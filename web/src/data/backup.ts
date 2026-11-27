// Резервная копия в том же формате JSON, что и в iOS-версии DayTrack:
// копию с iPhone можно загрузить сюда, а копию отсюда — обратно в приложение для iPhone.
import type { State } from './model'
import { emptyState } from './defaults'

const sf = ['book.fill', 'graduationcap.fill', 'lightbulb.fill', 'pencil.and.ruler.fill', 'laptopcomputer', 'function', 'character.book.closed.fill', 'brain.head.profile', 'leaf.fill', 'gamecontroller.fill', 'headphones', 'tv.fill', 'person.2.fill', 'moon.fill', 'bed.double.fill', 'figure.run', 'dumbbell.fill', 'fork.knife', 'cup.and.saucer.fill', 'house.fill', 'cart.fill', 'tram.fill', 'car.fill', 'briefcase.fill', 'phone.fill', 'heart.fill', 'cross.case.fill', 'circle.grid.2x2.fill']
const emoji = ['📘', '🎓', '💡', '✏️', '💻', '🧮', '📖', '🧠', '🌿', '🎮', '🎧', '📺', '👥', '🌙', '🛏️', '🏃', '🏋️', '🍽️', '☕', '🏠', '🛒', '🚋', '🚗', '💼', '📞', '❤️', '🩺', '⚪']
const toEmoji = (s: string) => emoji[sf.indexOf(s)] ?? (sf.includes(s) ? '⚪' : s || '⚪')
const toSF = (e: string) => sf[emoji.indexOf(e)] ?? 'circle.fill'

const iso = (t: number | null | undefined) => (t === null || t === undefined ? undefined : new Date(t).toISOString())
const ms = (s: string | null | undefined) => (s ? new Date(s).getTime() : null)
const hex = (c: string) => c.replace('#', '').toUpperCase()

/* eslint-disable @typescript-eslint/no-explicit-any */
export function exportSnapshot(s: State): any {
  return {
    formatVersion: 1,
    exportedAt: new Date().toISOString(),
    appVersion: 'web',
    firstWeekKey: s.settings.firstWeekKey ?? undefined,
    categories: s.categories.map((c) => ({ uuid: c.id, name: c.name, colorHex: hex(c.color), symbol: toSF(c.symbol), kindRaw: c.kind, sortOrder: c.order, isArchived: c.archived, keywordsRaw: c.keywords })),
    days: Object.values(s.days).sort((a, b) => a.key - b.key).map((d) => ({
      key: d.key, lockedAt: iso(d.lockedAt), planEditedAt: iso(d.planEditedAt), scheduleApplied: d.scheduleApplied,
      blocks: d.blocks.map((b) => ({ uuid: b.id, title: b.title, start: iso(b.start), end: iso(b.end), note: b.note, baselineStart: iso(b.baselineStart), baselineEnd: iso(b.baselineEnd), addedAfterLock: b.addedAfterLock, removedAt: iso(b.removedAt), missReasonRaw: b.missReason ?? undefined, sourceRaw: b.source, categoryUUID: b.categoryId ?? undefined, focusUUID: b.focusId ?? undefined, isFrog: b.isFrog })),
      tasks: d.tasks.map((t) => ({ uuid: t.id, title: t.title, estimateMinutes: t.estimate, isDone: t.done, sortOrder: t.order, createdAt: iso(t.createdAt), addedAfterLock: t.addedAfterLock, categoryUUID: t.categoryId ?? undefined, focusUUID: t.focusId ?? undefined })),
      facts: d.facts.map((f) => ({ uuid: f.id, title: f.title, start: iso(f.start), end: iso(f.end), note: f.note, reasonRaw: f.reason ?? undefined, categoryUUID: f.categoryId ?? undefined, blockUUID: f.blockId ?? undefined, focusUUID: f.focusId ?? undefined, projectUUID: f.projectId ?? undefined })),
      changes: d.changes.map((c) => ({ uuid: c.id, at: iso(c.at), kindRaw: c.kind, text: c.text, blockUUID: c.blockId ?? undefined })),
    })),
    reminders: s.reminders.map((r) => ({ uuid: r.id, title: r.title, note: r.note, firstDayKey: r.firstDay, minuteOfDay: r.minute ?? undefined, repeatRaw: r.repeat, notify: r.notify, leadDays: r.leadDays, createdAt: iso(r.createdAt) })),
    scheduleRules: s.scheduleRules.map((r) => ({ uuid: r.id, title: r.title, categoryUUID: r.categoryId ?? undefined, weekday: r.weekday, startMinute: r.startMinute, endMinute: r.endMinute, parityRaw: r.parity, validFromKey: r.validFrom ?? undefined, validUntilKey: r.validUntil ?? undefined, isEnabled: r.enabled })),
    templates: s.templates.map((t) => ({ uuid: t.id, name: t.name, itemsJSON: JSON.stringify(t.items.map((i) => ({ title: i.title, categoryUUID: i.categoryId ?? undefined, startMinute: i.startMinute, durationMinutes: i.durationMinutes }))), createdAt: iso(t.createdAt) })),
    focuses: s.focuses.map((f) => ({ uuid: f.id, title: f.title, why: f.why, periodRaw: f.period, periodStartKey: f.periodStart, parentUUID: f.parentId ?? undefined, statusRaw: f.status, result: f.result, sortOrder: f.order, createdAt: iso(f.createdAt) })),
    energyMarks: s.energy.map((m) => ({ uuid: m.id, at: iso(m.at), dayKey: m.day, energy: m.energy, mood: m.mood })),
    reflections: Object.values(s.reflections).map((r) => ({ dayKey: r.day, wentWell: r.wentWell, hindered: r.hindered, changeTomorrow: r.changeTomorrow, rating: r.rating, updatedAt: iso(r.updatedAt) })),
    projects: s.projects.map((p) => ({ uuid: p.id, title: p.title, why: p.why, categoryUUID: p.categoryId ?? undefined, minimumMinutes: p.minimum, ifThen: p.ifThen, stepsJSON: JSON.stringify(p.steps.map((x) => ({ id: x.id, title: x.title, minutes: x.minutes, isDone: x.done }))), createdAt: iso(p.createdAt), lastWorkedAt: iso(p.lastWorkedAt), isArchived: p.archived, nudgeOn: p.nudgeOn, nudgeMinute: p.nudgeMinute, sortOrder: p.order })),
    webSettings: s.settings,
  }
}

export function importSnapshot(j: any, current: State): State {
  if (!j || !Array.isArray(j.categories) || !Array.isArray(j.days)) throw new Error('Это не копия DayTrack')
  const s = emptyState()
  s.settings = j.webSettings ?? current.settings
  if (j.firstWeekKey) s.settings.firstWeekKey = j.firstWeekKey
  s.onboardingDone = true
  s.categories = j.categories.map((c: any) => ({ id: c.uuid, name: c.name, color: '#' + String(c.colorHex).replace('#', ''), symbol: toEmoji(c.symbol), kind: c.kindRaw, order: c.sortOrder, archived: !!c.isArchived, keywords: c.keywordsRaw ?? '' }))
  for (const d of j.days) {
    s.days[d.key] = {
      key: d.key, lockedAt: ms(d.lockedAt), planEditedAt: ms(d.planEditedAt), scheduleApplied: !!d.scheduleApplied,
      blocks: (d.blocks ?? []).map((b: any) => ({ id: b.uuid, title: b.title, start: ms(b.start)!, end: ms(b.end)!, note: b.note ?? '', categoryId: b.categoryUUID ?? null, baselineStart: ms(b.baselineStart), baselineEnd: ms(b.baselineEnd), addedAfterLock: !!b.addedAfterLock, removedAt: ms(b.removedAt), missReason: b.missReasonRaw ?? null, source: b.sourceRaw ?? 'manual', focusId: b.focusUUID ?? null, isFrog: !!b.isFrog })),
      tasks: (d.tasks ?? []).map((t: any) => ({ id: t.uuid, title: t.title, estimate: t.estimateMinutes ?? 0, done: !!t.isDone, order: t.sortOrder ?? 0, createdAt: ms(t.createdAt) ?? Date.now(), addedAfterLock: !!t.addedAfterLock, categoryId: t.categoryUUID ?? null, focusId: t.focusUUID ?? null })),
      facts: (d.facts ?? []).map((f: any) => ({ id: f.uuid, title: f.title, start: ms(f.start)!, end: ms(f.end)!, note: f.note ?? '', reason: f.reasonRaw ?? null, categoryId: f.categoryUUID ?? null, blockId: f.blockUUID ?? null, focusId: f.focusUUID ?? null, projectId: f.projectUUID ?? null })),
      changes: (d.changes ?? []).map((c: any) => ({ id: c.uuid, at: ms(c.at)!, kind: c.kindRaw, text: c.text, blockId: c.blockUUID ?? null })),
    }
  }
  s.reminders = (j.reminders ?? []).map((r: any) => ({ id: r.uuid, title: r.title, note: r.note ?? '', firstDay: r.firstDayKey, minute: r.minuteOfDay ?? null, repeat: r.repeatRaw ?? 'none', notify: r.notify !== false, leadDays: r.leadDays ?? 0, createdAt: ms(r.createdAt) ?? Date.now() }))
  s.scheduleRules = (j.scheduleRules ?? []).map((r: any) => ({ id: r.uuid, title: r.title, categoryId: r.categoryUUID ?? null, weekday: r.weekday, startMinute: r.startMinute, endMinute: r.endMinute, parity: r.parityRaw ?? 'every', validFrom: r.validFromKey ?? null, validUntil: r.validUntilKey ?? null, enabled: r.isEnabled !== false }))
  s.templates = (j.templates ?? []).map((t: any) => ({ id: t.uuid, name: t.name, createdAt: ms(t.createdAt) ?? Date.now(), items: (JSON.parse(t.itemsJSON || '[]') as any[]).map((i) => ({ title: i.title, categoryId: i.categoryUUID ?? null, startMinute: i.startMinute, durationMinutes: i.durationMinutes })) }))
  s.focuses = (j.focuses ?? []).map((f: any) => ({ id: f.uuid, title: f.title, why: f.why ?? '', period: f.periodRaw, periodStart: f.periodStartKey, parentId: f.parentUUID ?? null, status: f.statusRaw ?? 'active', result: f.result ?? '', order: f.sortOrder ?? 0, createdAt: ms(f.createdAt) ?? Date.now() }))
  s.energy = (j.energyMarks ?? []).map((m: any) => ({ id: m.uuid, at: ms(m.at)!, day: m.dayKey, energy: m.energy, mood: m.mood }))
  for (const r of j.reflections ?? []) s.reflections[r.dayKey] = { day: r.dayKey, wentWell: r.wentWell ?? '', hindered: r.hindered ?? '', changeTomorrow: r.changeTomorrow ?? '', rating: r.rating ?? 0, updatedAt: ms(r.updatedAt) ?? Date.now() }
  s.projects = (j.projects ?? []).map((p: any) => ({ id: p.uuid, title: p.title, why: p.why ?? '', categoryId: p.categoryUUID ?? null, minimum: p.minimumMinutes ?? 5, ifThen: p.ifThen ?? '', steps: (JSON.parse(p.stepsJSON || '[]') as any[]).map((x) => ({ id: x.id, title: x.title, minutes: x.minutes, done: !!x.isDone })), createdAt: ms(p.createdAt) ?? Date.now(), lastWorkedAt: ms(p.lastWorkedAt), archived: !!p.isArchived, nudgeOn: p.nudgeOn !== false, nudgeMinute: p.nudgeMinute ?? 1140, order: p.sortOrder ?? 0 }))
  return s
}

export function summaryOf(j: any): string {
  const facts = (j.days ?? []).reduce((n: number, d: any) => n + (d.facts?.length ?? 0), 0)
  return `Дней: ${j.days?.length ?? 0}, записей факта: ${facts}, напоминаний: ${j.reminders?.length ?? 0}`
}

export function backupFileName(date = new Date()) {
  const p = (n: number) => String(n).padStart(2, '0')
  return `DayTrack-${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}_${p(date.getHours())}-${p(date.getMinutes())}.json`
}
