import { emptyState, defaultCategories } from './defaults'
import type { Block, Category, Day, Fact, Focus, ID, Project, Session, SessionMode, State, Task, TemplateItem } from './model'
import { uid } from './model'
import { addDays, DayKey, endAfter, fmtRange, keyOf, minutesBetween, minuteOfDay, resolve, todayKey, windowOf } from '../core/time'
import { emptyComparison, evaluate, DayComparison } from '../core/comparison'
import { bestMatch, parseKeywords } from '../core/keywords'
import { defaultFirstWeekKey, periodRange, ruleApplies } from '../core/periods'
import type { Reason, CategoryKind } from '../core/kinds'
import { advise, Advice, AdviceAction, AdvisorBlock } from '../core/advisor'
import { averageByHour, countLastDays, median, softStreak } from '../core/stats'

const STORAGE_KEY = 'daytrack.v1'

// MARK: Хранилище

let state: State = load()
let version = 0
const listeners = new Set<() => void>()

function load(): State {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) return migrate(JSON.parse(raw))
  } catch { /* повреждённые данные: начинаем заново, копия остаётся в localStorage под другим ключом */ }
  return emptyState()
}

/** Добавляет поля, появившиеся в новых версиях. */
function migrate(s: State): State {
  const base = emptyState()
  const merged = { ...base, ...s, settings: { ...base.settings, ...s.settings } } as State
  merged.settings.notify = { ...base.settings.notify, ...s.settings?.notify }
  merged.settings.advisor = { ...base.settings.advisor, ...s.settings?.advisor }
  merged.settings.games = { ...base.settings.games, ...s.settings?.games }
  merged.settings.target = { ...base.settings.target, ...s.settings?.target }
  if (!merged.categories?.length) merged.categories = defaultCategories()
  return merged
}

let saveTimer: number | undefined
export function commit() {
  version++
  listeners.forEach((l) => l())
  clearTimeout(saveTimer)
  saveTimer = window.setTimeout(persist, 150)
}

export function persist() {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)) } catch (e) { console.error('Не удалось сохранить', e) }
}

export function subscribe(listener: () => void) {
  listeners.add(listener)
  return () => { listeners.delete(listener) }
}
export const getVersion = () => version
export const getState = () => state

export function replaceState(next: State) {
  state = migrate(next)
  commit()
  persist()
}

// MARK: Дни

export function day(key: DayKey): Day | undefined { return state.days[key] }

export function ensureDay(key: DayKey): Day {
  let d = state.days[key]
  if (!d) {
    d = { key, lockedAt: null, planEditedAt: null, scheduleApplied: false, blocks: [], tasks: [], facts: [], changes: [] }
    state.days[key] = d
  }
  return d
}

export const activeBlocks = (d: Day | undefined) => (d?.blocks ?? []).filter((b) => b.removedAt === null)
export const category = (id: ID | null | undefined): Category | undefined => state.categories.find((c) => c.id === id)
export const kindOf = (id: ID | null | undefined): CategoryKind => category(id)?.kind ?? 'other'
export const blockOf = (d: Day | undefined, id: ID | null | undefined) => d?.blocks.find((b) => b.id === id)

export interface DaySummary { current: DayComparison; baseline: DayComparison | null; planWasEdited: boolean; status: (id: ID) => ReturnType<DayComparison['blocks']['find']> }

export function summary(d: Day | undefined, now = Date.now()): DaySummary {
  if (!d) return { current: emptyComparison, baseline: null, planWasEdited: false, status: () => undefined }
  const facts = d.facts.map((f) => ({ id: f.id, planId: f.blockId, start: f.start, end: f.end }))
  const current = evaluate(activeBlocks(d).map((b) => ({ id: b.id, start: b.start, end: b.end, markedMissed: b.missReason !== null })), facts, now)
  const baseline = d.lockedAt !== null
    ? evaluate(d.blocks.filter((b) => b.baselineStart !== null).map((b) => ({ id: b.id, start: b.baselineStart!, end: b.baselineEnd!, markedMissed: b.missReason !== null || b.removedAt !== null })), facts, now)
    : null
  return { current, baseline, planWasEdited: d.changes.length > 0, status: (id) => current.blocks.find((b) => b.id === id) }
}

// MARK: Фиксация плана

export function lock(d: Day, at = Date.now()) {
  if (d.lockedAt !== null) return
  d.lockedAt = at
  for (const b of d.blocks) { b.baselineStart = b.start; b.baselineEnd = b.end; b.addedAfterLock = false }
  for (const t of d.tasks) t.addedAfterLock = false
  commit()
}

export const canUnlock = (d: Day | undefined) => !!d && d.lockedAt !== null && d.facts.length === 0

export function unlock(d: Day) {
  if (!canUnlock(d)) return
  d.blocks = d.blocks.filter((b) => b.removedAt === null)
  for (const b of d.blocks) { b.baselineStart = null; b.baselineEnd = null; b.addedAfterLock = false }
  for (const t of d.tasks) t.addedAfterLock = false
  d.changes = []
  d.lockedAt = null
  d.planEditedAt = Date.now()
  commit()
}

/** План фиксируется сам, когда наступило время первого блока и его не меняли 15 минут. */
export function autoLock(key: DayKey, now = Date.now()) {
  const d = day(key)
  if (!d || d.lockedAt !== null || !d.blocks.length) return
  const first = Math.min(...d.blocks.map((b) => b.start))
  if (first > now) return
  if (d.planEditedAt && now - d.planEditedAt < 15 * 60000) return
  lock(d, now)
}

function log(d: Day, kind: 'added' | 'removed' | 'edited', text: string, blockId: ID) {
  d.changes.push({ id: uid(), at: Date.now(), kind, text, blockId })
}

// MARK: Блоки

export interface BlockInput { title: string; categoryId: ID | null; start: number; end: number; note: string; focusId?: ID | null; isFrog?: boolean }

export function addBlock(key: DayKey, input: BlockInput, source: Block['source'] = 'manual'): Block {
  const d = ensureDay(key)
  const b: Block = {
    id: uid(), title: input.title, start: input.start, end: input.end, note: input.note, categoryId: input.categoryId,
    baselineStart: null, baselineEnd: null, addedAfterLock: false, removedAt: null, missReason: null, source,
    focusId: input.focusId ?? null, isFrog: false,
  }
  d.blocks.push(b)
  if (d.lockedAt !== null) { b.addedAfterLock = true; log(d, 'added', `Добавлен блок «${b.title}» ${fmtRange(b.start, b.end)}`, b.id) }
  else d.planEditedAt = Date.now()
  if (input.isFrog) setFrog(d, b, true)
  commit()
  return b
}

export function updateBlock(d: Day, b: Block, input: BlockInput) {
  if (d.lockedAt !== null) {
    const parts: string[] = []
    if (b.start !== input.start || b.end !== input.end) parts.push(`${fmtRange(b.start, b.end)} → ${fmtRange(input.start, input.end)}`)
    if (b.title !== input.title) parts.push(`новое название «${input.title}»`)
    if (b.categoryId !== input.categoryId) parts.push(`категория ${category(b.categoryId)?.name ?? 'без категории'} → ${category(input.categoryId)?.name ?? 'без категории'}`)
    if (parts.length) log(d, 'edited', `«${b.title}»: ${parts.join(', ')}`, b.id)
  } else d.planEditedAt = Date.now()
  Object.assign(b, { title: input.title, categoryId: input.categoryId, start: input.start, end: input.end, note: input.note })
  if (input.focusId !== undefined) b.focusId = input.focusId
  if (input.isFrog !== undefined) setFrog(d, b, input.isFrog)
  commit()
}

/** После фиксации блок исходного плана не стирается, а помечается удалённым. */
export function deleteBlock(d: Day, b: Block) {
  if (d.lockedAt !== null) {
    log(d, 'removed', `Удалён блок «${b.title}» ${fmtRange(b.start, b.end)}`, b.id)
    if (b.baselineStart !== null) { b.removedAt = Date.now(); commit(); return }
  } else d.planEditedAt = Date.now()
  d.blocks = d.blocks.filter((x) => x !== b)
  for (const f of d.facts) if (f.blockId === b.id) f.blockId = null
  commit()
}

export function markMissed(b: Block, reason: Reason | null) { b.missReason = reason; commit() }

export function setFrog(d: Day, b: Block, value: boolean) {
  if (value) for (const o of d.blocks) if (o !== b) o.isFrog = false
  b.isFrog = value
  commit()
}

// MARK: Факт

export interface FactInput { title: string; categoryId: ID | null; start: number; end: number; reason: Reason | null; note: string; blockId: ID | null; focusId?: ID | null; projectId?: ID | null }

export function addFact(key: DayKey, input: FactInput): Fact {
  const d = ensureDay(key)
  if (d.lockedAt === null && d.blocks.length) lock(d)
  const f: Fact = { id: uid(), title: input.title, start: input.start, end: input.end, note: input.note, reason: input.reason, categoryId: input.categoryId, blockId: input.blockId, focusId: input.focusId ?? null, projectId: input.projectId ?? null }
  d.facts.push(f)
  const b = blockOf(d, input.blockId)
  if (b) b.missReason = null
  commit()
  return f
}

export function updateFact(d: Day, f: Fact, input: FactInput) {
  Object.assign(f, { title: input.title, categoryId: input.categoryId, start: input.start, end: input.end, reason: input.reason, note: input.note, blockId: input.blockId })
  if (input.focusId !== undefined) f.focusId = input.focusId
  const b = blockOf(d, input.blockId)
  if (b) b.missReason = null
  commit()
}

export function deleteFact(d: Day, f: Fact) { d.facts = d.facts.filter((x) => x !== f); commit() }

export const effectiveFocus = (d: Day, f: Fact) => f.focusId ?? blockOf(d, f.blockId)?.focusId ?? null

// MARK: Задачи

export function addTask(key: DayKey, title: string) {
  const d = ensureDay(key)
  const order = Math.max(-1, ...d.tasks.map((t) => t.order)) + 1
  d.tasks.push({ id: uid(), title, estimate: 0, done: false, order, createdAt: Date.now(), addedAfterLock: d.lockedAt !== null, categoryId: matchCategory(title)?.id ?? null, focusId: null })
  commit()
}
export function toggleTask(t: Task) { t.done = !t.done; commit() }
export function deleteTask(d: Day, t: Task) { d.tasks = d.tasks.filter((x) => x !== t); commit() }

// MARK: Категории по ключевым словам

export function matchCategory(title: string): Category | undefined {
  const active = state.categories.filter((c) => !c.archived).sort((a, b) => a.order - b.order)
  const i = bestMatch(title, active.map((c) => parseKeywords(c.keywords)))
  return i === null ? undefined : active[i]
}

export const categoryInUse = (id: ID) => Object.values(state.days).some((d) =>
  d.blocks.some((b) => b.categoryId === id) || d.facts.some((f) => f.categoryId === id) || d.tasks.some((t) => t.categoryId === id))

export function gamesCategory(): Category {
  let c = state.categories.find((x) => x.name.toLowerCase() === 'игры')
  if (!c) {
    c = { id: uid(), name: 'Игры', color: '#E056A0', symbol: '🎮', kind: 'rest', order: state.categories.length, archived: false, keywords: 'игры, игра, играть, поиграть, game' }
    state.categories.push(c)
    commit()
  }
  return c
}

// MARK: Расписание и шаблоны

export const firstWeekKey = () => state.settings.firstWeekKey ?? defaultFirstWeekKey(todayKey())

export function rulesFor(key: DayKey) {
  return state.scheduleRules.filter((r) => ruleApplies({ weekday: r.weekday, parity: r.parity, validFrom: r.validFrom, validUntil: r.validUntil, enabled: r.enabled }, key, firstWeekKey()))
    .sort((a, b) => a.startMinute - b.startMinute)
}

export function autoApplySchedule(key: DayKey) {
  if (key < todayKey()) return
  const d = day(key)
  if (d && (d.scheduleApplied || d.lockedAt !== null)) return
  if (!rulesFor(key).length) return
  applySchedule(key)
}

export function applySchedule(key: DayKey): number {
  const d = ensureDay(key)
  let added = 0
  for (const r of rulesFor(key)) {
    const start = resolve(Math.floor(r.startMinute / 60), r.startMinute % 60, key)
    const end = endAfter(start, r.endMinute)
    if (activeBlocks(d).some((b) => b.title === r.title && b.start === start)) continue
    addBlock(key, { title: r.title, categoryId: r.categoryId, start, end, note: '' }, 'schedule')
    added++
  }
  d.scheduleApplied = true
  commit()
  return added
}

export function applyTemplate(templateId: ID, key: DayKey) {
  const t = state.templates.find((x) => x.id === templateId)
  if (!t) return
  for (const item of t.items) {
    const start = resolve(Math.floor(item.startMinute / 60), item.startMinute % 60, key)
    addBlock(key, { title: item.title, categoryId: item.categoryId, start, end: start + item.durationMinutes * 60000, note: '' }, 'template')
  }
}

export function saveTemplate(name: string, d: Day) {
  const items: TemplateItem[] = activeBlocks(d).sort((a, b) => a.start - b.start)
    .map((b) => ({ title: b.title, categoryId: b.categoryId, startMinute: minuteOfDay(b.start), durationMinutes: minutesBetween(b.start, b.end) }))
  state.templates.push({ id: uid(), name, items, createdAt: Date.now() })
  commit()
}

// MARK: Фокусы

export function focusRange(f: Focus): [DayKey, DayKey] { return periodRange(f.period, f.periodStart) }
export const focusAvailable = (f: Focus, key: DayKey) => { const [a, b] = focusRange(f); return f.status !== 'dropped' && key >= a && key <= b }

export interface FocusProgress { minutes: number; done: number; total: number }
export function focusProgress(focuses: Focus[], days: Day[]): Map<ID, FocusProgress> {
  const parent = new Map<ID, ID>()
  for (const f of focuses) if (f.parentId) parent.set(f.id, f.parentId)
  const result = new Map<ID, FocusProgress>()
  const add = (id: ID, minutes = 0, done = 0, total = 0) => {
    for (const target of [id, parent.get(id)]) {
      if (!target) continue
      const p = result.get(target) ?? { minutes: 0, done: 0, total: 0 }
      p.minutes += minutes; p.done += done; p.total += total
      result.set(target, p)
    }
  }
  for (const d of days) {
    const s = summary(d)
    for (const f of d.facts) { const id = effectiveFocus(d, f); if (id) add(id, minutesBetween(f.start, f.end)) }
    for (const b of activeBlocks(d)) if (b.focusId) add(b.focusId, 0, s.status(b.id)?.status === 'done' ? 1 : 0, 1)
    for (const t of d.tasks) if (t.focusId) add(t.focusId, 0, t.done ? 1 : 0, 1)
  }
  return result
}

export function daysInRange(from: DayKey, to: DayKey): Day[] {
  return Object.values(state.days).filter((d) => d.key >= from && d.key <= to)
}

// MARK: Большие дела

export function daysIdle(p: Project, now = Date.now()): number {
  const last = p.lastWorkedAt ?? p.createdAt
  const a = new Date(last); a.setHours(0, 0, 0, 0)
  const b = new Date(now); b.setHours(0, 0, 0, 0)
  return Math.round((b.getTime() - a.getTime()) / 86400000)
}
export const workedToday = (p: Project) => p.lastWorkedAt !== null && keyOf(p.lastWorkedAt) === todayKey()
export const nextStep = (p: Project) => p.steps.find((s) => !s.done)

// MARK: Сессии: отдых, фокус, игра

export function startSession(mode: SessionMode, minutes: number, label: string, projectId: ID | null = null) {
  const now = Date.now()
  state.session = { mode, startedAt: now, endsAt: now + minutes * 60000, label, projectId }
  state.firedNotifications = state.firedNotifications.filter((id) => !id.startsWith('session-'))
  commit()
}

export function cancelSession() { state.session = null; commit() }

export interface SessionResult { mode: SessionMode; planned: number; actual: number; projectId: ID | null; label: string }

export function finishSession(): SessionResult | null {
  const s: Session | null = state.session
  if (!s) return null
  state.session = null
  const end = Date.now()
  const result: SessionResult = { mode: s.mode, planned: minutesBetween(s.startedAt, s.endsAt), actual: minutesBetween(s.startedAt, end), projectId: s.projectId, label: s.label }
  if (result.actual < 1) { commit(); return result }
  const key = keyOf(s.startedAt)
  const d = day(key)
  const overlapping = (pred: (b: Block) => boolean) => {
    let best: Block | undefined, bestOverlap = 0
    for (const b of activeBlocks(d)) {
      if (!pred(b)) continue
      const o = Math.min(end, b.end) - Math.max(s.startedAt, b.start)
      if (o > bestOverlap) { bestOverlap = o; best = b }
    }
    return best
  }
  const cats = [...state.categories].sort((a, b) => a.order - b.order)
  if (s.mode === 'rest') {
    const b = overlapping((x) => kindOf(x.categoryId) === 'rest')
    const rest = cats.find((c) => c.kind === 'rest' && !c.archived && c.name.toLowerCase() !== 'игры')
    addFact(key, { title: b?.title ?? 'Отдых', categoryId: b?.categoryId ?? rest?.id ?? null, start: s.startedAt, end, reason: b ? null : 'other', note: '', blockId: b?.id ?? null })
  } else if (s.mode === 'game') {
    const games = gamesCategory()
    const b = overlapping((x) => x.categoryId === games.id)
    addFact(key, { title: b?.title ?? 'Игры', categoryId: games.id, start: s.startedAt, end, reason: b ? null : 'other', note: '', blockId: b?.id ?? null })
  } else {
    const p = state.projects.find((x) => x.id === s.projectId)
    const cat = cats.find((c) => c.id === p?.categoryId) ?? cats.find((c) => c.kind === 'study' && !c.archived)
    const b = overlapping((x) => x.categoryId === cat?.id)
    const title = p ? (s.label ? `${p.title}: ${s.label}` : p.title) : (s.label || 'Фокус')
    addFact(key, { title, categoryId: cat?.id ?? null, start: s.startedAt, end, reason: b ? null : 'other', note: '', blockId: b?.id ?? null, projectId: p?.id ?? null })
    if (p) p.lastWorkedAt = end
  }
  commit()
  return result
}

export function gameWeekStats() {
  const [from, to] = periodRange('week', todayKey())
  const games = gamesCategory().id
  let played = 0, studied = 0
  for (const d of daysInRange(from, to)) for (const f of d.facts) {
    const m = minutesBetween(f.start, f.end)
    if (f.categoryId === games) played += m
    else if (kindOf(f.categoryId) === 'study') studied += m
  }
  return { played, studied }
}

export function gameRemaining() {
  const { played, studied } = gameWeekStats()
  const g = state.settings.games
  return Math.max((g.earnByStudy ? Math.min(studied, g.budget) : g.budget) - played, 0)
}

// MARK: Советчик и серии

export function awakeMinutes() {
  const s = state.settings
  const span = ((s.bedMinute - s.wakeMinute) % 1440 + 1440) % 1440
  return span === 0 ? 960 : span
}

export function adviceFor(key: DayKey, now = Date.now()): Advice[] {
  const d = day(key)
  const win = windowOf(key)
  const blocks: AdvisorBlock[] = activeBlocks(d).map((b) => ({
    id: b.id, title: b.title, start: b.start, end: b.end, kind: kindOf(b.categoryId), categoryId: b.categoryId,
    categoryName: category(b.categoryId)?.name, isFrog: b.isFrog, hasFact: !!d?.facts.some((f) => f.blockId === b.id),
  }))
  const history = daysInRange(addDays(key, -28), addDays(key, -1))
  const ratios = new Map<string, number[]>()
  for (const past of history) for (const b of activeBlocks(past)) {
    if (!b.categoryId) continue
    const planned = minutesBetween(b.start, b.end)
    const fact = past.facts.filter((f) => f.blockId === b.id).reduce((s, f) => s + minutesBetween(f.start, f.end), 0)
    if (planned > 0 && fact > 0) ratios.set(b.categoryId, [...(ratios.get(b.categoryId) ?? []), fact / planned])
  }
  const estimateHistory = new Map([...ratios].map(([id, list]) => [id, { ratio: median(list), samples: list.length }]))
  let daysWithoutPlan = 0
  let k = addDays(key, -1)
  while (daysWithoutPlan < 7 && !activeBlocks(day(k)).length) { daysWithoutPlan++; k = addDays(k, -1) }
  const marks = state.energy.filter((m) => m.day >= addDays(key, -14) && m.day <= key)
  let best: number[] = []
  if (marks.length >= 8 && new Set(marks.map((m) => m.day)).size >= 5) {
    const avg = averageByHour(marks.map((m) => ({ at: m.at, value: m.energy })))
    const top = Math.max(...avg.values())
    best = [...avg].filter(([, v]) => v >= top - 0.25).map(([h]) => h).sort((a, b) => a - b)
  }
  const [ws] = periodRange('week', key)
  let weekStudy = 0, elapsed = 0
  if (ws < key) {
    const prev = daysInRange(ws, addDays(key, -1)).filter((x) => x.facts.length > 0)
    elapsed = prev.length
    for (const d2 of prev) for (const f of d2.facts) if (kindOf(f.categoryId) === 'study') weekStudy += minutesBetween(f.start, f.end)
  }
  const s = state.settings
  const dismissed = new Set(state.dismissedAdvice[key] ?? [])
  return advise({
    blocks, taskEstimates: (d?.tasks ?? []).filter((t) => !t.done).map((t) => t.estimate), window: win, now,
    awakeMinutes: awakeMinutes(), estimateHistory, daysWithoutPlan, bestEnergyHours: best, weekStudyMinutes: weekStudy, weekDaysElapsed: elapsed,
  }, {
    loadLimit: s.advisor.loadPercent / 100, bufferMinutes: s.advisor.buffer, breakInterval: s.notify.breakInterval,
    studyCeiling: s.advisor.ceiling, minSleep: 420, studyTarget: s.target.study, disabled: s.advisor.disabled,
  }).filter((a) => !dismissed.has(a.rule))
}

export function applyAdvice(action: AdviceAction, key: DayKey) {
  const d = ensureDay(key)
  if (action.type === 'markFrog') { const b = blockOf(d, action.blockId); if (b) setFrog(d, b, true) }
  else if (action.type === 'extendCategory') {
    for (const b of activeBlocks(d).filter((x) => x.categoryId === action.categoryId)) {
      const extra = Math.round(((b.end - b.start) * (action.ratio - 1)) / 300000) * 300000
      updateBlock(d, b, { title: b.title, categoryId: b.categoryId, start: b.start, end: b.end + extra, note: b.note })
    }
  } else {
    const cat = [...state.categories].sort((a, b) => a.order - b.order).find((c) => c.kind === action.kind && !c.archived && c.name.toLowerCase() !== 'игры')
    addBlock(key, { title: action.title, categoryId: cat?.id ?? null, start: action.start, end: action.start + action.minutes * 60000, note: '' })
  }
}

export function dismissAdvice(rule: string, key: DayKey) {
  state.dismissedAdvice[key] = [...(state.dismissedAdvice[key] ?? []), rule]
  commit()
}

export function streak(today = todayKey()) {
  const done = new Set<DayKey>()
  for (const d of daysInRange(addDays(today, -120), today)) {
    const r = state.reflections[d.key]
    if (activeBlocks(d).length && r && (r.wentWell || r.hindered || r.changeTomorrow || r.rating)) done.add(d.key)
  }
  return { streak: softStreak(done, today), last30: countLastDays(done, 30, today) }
}

export const isReflectionEmpty = (key: DayKey) => {
  const r = state.reflections[key]
  return !r || !(r.wentWell || r.hindered || r.changeTomorrow || r.rating)
}

