import { activeBlocks, category, daysInRange, focusProgress, focusRange, getState, summary } from './store'
import { groupMinutes, periodData } from './analytics'
import { todayKey, DayKey, duration, fmtDayLong, fmtDayTiny, fmtRange, fmtTime, minutesBetween, percent } from '../core/time'
import { periodRange, PeriodKind, shiftPeriod } from '../core/periods'
import { balanceGroups, groupOf, reasonTitle } from '../core/kinds'
import { defaultPrompt } from './defaults'
import type { Focus } from './model'

export const promptText = () => getState().settings.prompt?.trim() || defaultPrompt

function focusLines(focuses: Focus[], from: DayKey, to: DayKey): string[] {
  const progress = focusProgress(focuses, daysInRange(from, to))
  return focuses.map((f) => {
    const p = progress.get(f.id) ?? { minutes: 0, done: 0, total: 0 }
    const parent = focuses.find((x) => x.id === f.parentId)
    let line = `- ${f.title} (${f.period === 'week' ? 'неделя' : 'месяц'})`
    if (parent) line += `, шаг к «${parent.title}»`
    line += `: ${p.minutes ? duration(p.minutes) : '0 ч'}${p.total ? `, дел ${p.done} из ${p.total}` : ''}`
    if (f.status !== 'active') line += `, итог: ${f.status === 'done' ? 'получилось' : 'отложено'}`
    if (f.why) line += `. Зачем: ${f.why}`
    if (f.result) line += `. Итог своими словами: ${f.result}`
    return line
  })
}

const overlapping = (range: [DayKey, DayKey]) => getState().focuses.filter((f) => {
  const [a, b] = focusRange(f)
  return f.status !== 'dropped' && a <= range[1] && b >= range[0]
})

export function buildReport(kind: PeriodKind, anchor: DayKey): string {
  return kind === 'day' ? dayReport(anchor) : periodReport(kind, periodRange(kind, anchor))
}

function dayReport(key: DayKey): string {
  const st = getState()
  const d = st.days[key]
  const s = summary(d)
  const lines = [`ОТЧЁТ ЗА ДЕНЬ: ${fmtDayLong(key)}`, '']
  const focuses = overlapping([key, key])
  if (focuses.length) {
    const w = periodRange('week', key), m = periodRange('month', key)
    lines.push('ФОКУСЫ', ...focusLines(focuses, Math.min(w[0], m[0]), Math.max(w[1], m[1])), '')
  }
  const blocks = activeBlocks(d).sort((a, b) => a.start - b.start)
  if (!blocks.length) lines.push('ПЛАНА НА ЭТОТ ДЕНЬ НЕ БЫЛО')
  else {
    lines.push('ПЛАН → ФАКТ')
    for (const b of blocks) {
      const cat = category(b.categoryId)
      const facts = (d?.facts ?? []).filter((f) => f.blockId === b.id).sort((x, y) => x.start - y.start)
      const r = s.status(b.id)
      let line = `${fmtRange(b.start, b.end)} ${b.isFrog ? '🐸 ' : ''}${b.title}${cat ? ` [${cat.name}]` : ''} → `
      if (facts.length) line += facts.map((f) => fmtRange(f.start, f.end)).join(', ')
      if (r?.status === 'done') line += facts.length ? ', выполнено' : 'выполнено'
      else if (r?.status === 'partial') line += `, частично (${r.factMinutes} из ${r.plannedMinutes} мин)`
      else if (r?.status === 'missed') line += 'не выполнено'
      else line += 'ещё не наступило'
      const reason = b.missReason ?? facts.find((f) => f.reason)?.reason
      if (reason) line += `, причина: ${reasonTitle(reason).toLowerCase()}`
      lines.push(line)
    }
  }
  const unplanned = (d?.facts ?? []).filter((f) => !f.blockId).sort((a, b) => a.start - b.start)
  if (unplanned.length) {
    lines.push('', 'ВНЕ ПЛАНА')
    for (const f of unplanned) lines.push(`${fmtRange(f.start, f.end)} ${f.title}${category(f.categoryId) ? ` [${category(f.categoryId)!.name}]` : ''}, причина: ${reasonTitle(f.reason).toLowerCase()}`)
  }
  if (d?.changes.length) {
    lines.push('', 'ПРАВКИ ПЛАНА ПОСЛЕ ФИКСАЦИИ')
    for (const c of [...d.changes].sort((a, b) => a.at - b.at)) lines.push(`${fmtTime(c.at)} ${c.text}`)
  }
  lines.push('', 'ИТОГИ')
  if (s.current.completion !== null) {
    let line = `Выполнение плана: ${percent(s.current.completion)}`
    if (s.planWasEdited && s.baseline?.completion != null) line += ` (к исходному плану без правок: ${percent(s.baseline.completion)})`
    lines.push(line)
  }
  const planned: Record<string, number> = {}, fact: Record<string, number> = {}
  for (const b of blocks) { const g = groupOf(category(b.categoryId)?.kind ?? 'other'); planned[g] = (planned[g] ?? 0) + minutesBetween(b.start, b.end) }
  for (const f of d?.facts ?? []) { const g = groupOf(category(f.categoryId)?.kind ?? 'other'); fact[g] = (fact[g] ?? 0) + minutesBetween(f.start, f.end) }
  for (const g of balanceGroups) if (planned[g.id] || fact[g.id]) lines.push(`${g.title}: план ${duration(planned[g.id] ?? 0)}, факт ${duration(fact[g.id] ?? 0)}`)
  const tasks = [...(d?.tasks ?? [])].sort((a, b) => a.order - b.order)
  if (tasks.length) lines.push(`Задачи без времени: сделано ${tasks.filter((t) => t.done).length} из ${tasks.length}: ${tasks.map((t) => (t.done ? '✓ ' : '✗ ') + t.title).join('; ')}`)
  const marks = st.energy.filter((m) => m.day === key).sort((a, b) => a.at - b.at)
  if (marks.length) lines.push(`Энергия и настроение (из 5): ${marks.map((m) => `${fmtTime(m.at)} — энергия ${m.energy}, настроение ${m.mood}`).join('; ')}`)
  const r = st.reflections[key]
  if (r && (r.wentWell || r.hindered || r.changeTomorrow || r.rating)) {
    lines.push('', 'РЕФЛЕКСИЯ')
    if (r.wentWell) lines.push(`Получилось: ${r.wentWell}`)
    if (r.hindered) lines.push(`Помешало: ${r.hindered}`)
    if (r.changeTomorrow) lines.push(`Завтра изменю: ${r.changeTomorrow}`)
    if (r.rating) lines.push(`Оценка дня: ${r.rating} из 5`)
  }
  return lines.join('\n')
}

function periodReport(kind: PeriodKind, range: [DayKey, DayKey]): string {
  const st = getState()
  const data = periodData(range, kind)
  const lines = [`ОТЧЁТ ЗА ${kind === 'week' ? 'НЕДЕЛЮ' : 'МЕСЯЦ'}: ${fmtDayLong(range[0], false)} – ${fmtDayLong(range[1], false)}`, '']
  const focuses = overlapping(range)
  if (focuses.length) lines.push('ФОКУСЫ', ...focusLines(focuses, range[0], range[1]), '')
  lines.push('ПО ДНЯМ')
  const today = todayKey()
  for (const p of data.days.filter((x) => x.key <= today)) {
    const parts = [p.completion !== null ? `план ${duration(p.planned)}, выполнено ${percent(p.completion)}` : 'плана не было']
    const g = groupMinutes(p.byKind)
    for (const b of balanceGroups) if (g[b.id]) parts.push(`${b.title.toLowerCase()} ${duration(g[b.id])}`)
    if (p.unplanned) parts.push(`вне плана ${duration(p.unplanned)}`)
    if (!p.fact) parts.push('факт не внесён')
    lines.push(`${fmtDayTiny(p.key)}: ${parts.join(', ')}`)
  }
  lines.push('', 'ИТОГИ')
  if (data.completion !== null) {
    const prevRange = periodRange(kind, shiftPeriod(range[0], kind, -1))
    const prev = periodData(prevRange, kind)
    lines.push(`Выполнение плана за период: ${percent(data.completion)}${prev.completion !== null ? ` (в прошлом периоде: ${percent(prev.completion)})` : ''}`)
  }
  lines.push(`Дней с планом: ${data.days.filter((d) => d.planned > 0).length} из ${data.days.length}`)
  const g = groupMinutes(data.byKind)
  const withFact = Math.max(data.days.filter((d) => d.fact > 0).length, 1)
  for (const b of balanceGroups) if (g[b.id]) lines.push(`${b.title}: всего ${duration(g[b.id])}, в среднем ${duration(g[b.id] / withFact)} в день`)
  if (data.reasons.length) { lines.push('', 'ЧТО СБИВАЛО С ПЛАНА'); for (const r of data.reasons) lines.push(`${reasonTitle(r.reason)}: ${r.count}`) }
  const est = data.categories.filter((c) => c.ratio && c.ratio > 0)
  if (est.length) {
    lines.push('', 'ТОЧНОСТЬ ОЦЕНОК ВРЕМЕНИ (факт к плану по выполненным блокам)')
    for (const c of est) { const p = Math.round((c.ratio! - 1) * 100); lines.push(`${c.name}: ${p === 0 ? 'точно' : p > 0 ? `дольше на ${p}%` : `быстрее на ${-p}%`}`) }
  }
  if (data.bestEnergyHours.length) lines.push('', `Больше всего энергии в часы: ${data.bestEnergyHours.map((h) => `${h}:00`).join(', ')}`)
  const refl = Object.values(st.reflections).filter((r) => r.day >= range[0] && r.day <= range[1] && (r.wentWell || r.hindered || r.changeTomorrow || r.rating)).sort((a, b) => a.day - b.day)
  if (refl.length) {
    lines.push('', 'РЕФЛЕКСИЯ ПО ДНЯМ')
    for (const r of refl) {
      const parts: string[] = []
      if (r.wentWell) parts.push(`получилось: ${r.wentWell}`)
      if (r.hindered) parts.push(`помешало: ${r.hindered}`)
      if (r.changeTomorrow) parts.push(`изменю: ${r.changeTomorrow}`)
      if (r.rating) parts.push(`оценка ${r.rating}/5`)
      lines.push(`${fmtDayTiny(r.day)}: ${parts.join('; ')}`)
    }
  }
  const games = st.categories.find((c) => c.name.toLowerCase() === 'игры')
  if (games) {
    const played = daysInRange(range[0], range[1]).flatMap((d) => d.facts).filter((f) => f.categoryId === games.id).reduce((a, f) => a + minutesBetween(f.start, f.end), 0)
    if (played) lines.push('', `Игры за период: ${duration(played)}`)
  }
  return lines.join('\n')
}
