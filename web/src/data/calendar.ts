import * as S from './store'
import type { CategoryKind } from '../core/kinds'
import { DayKey, endAfter, minutesBetween, resolve, todayKey } from '../core/time'
import { occurs } from '../core/periods'

/** Что запланировано на день: блоки плана, занятия расписания (если ещё не подставлены) и напоминания. */
export interface CalendarEntry {
  id: string
  start: number | null
  end: number | null
  title: string
  color: string
  kind: CategoryKind | null
  source: 'block' | 'schedule' | 'reminder'
}

export function calendarEntries(key: DayKey): CalendarEntry[] {
  const st = S.getState()
  const d = st.days[key]
  const out: CalendarEntry[] = S.activeBlocks(d).map((b) => {
    const c = S.category(b.categoryId)
    return { id: b.id, start: b.start, end: b.end, title: b.title, color: c?.color ?? '#7F8C8D', kind: c?.kind ?? null, source: 'block' }
  })
  if (key >= todayKey() && !d?.scheduleApplied && !d?.lockedAt) {
    for (const r of S.rulesFor(key)) {
      const start = resolve(Math.floor(r.startMinute / 60), r.startMinute % 60, key)
      const c = S.category(r.categoryId)
      out.push({ id: `rule-${r.id}`, start, end: endAfter(start, r.endMinute), title: r.title, color: c?.color ?? '#7F8C8D', kind: c?.kind ?? null, source: 'schedule' })
    }
  }
  for (const r of st.reminders) {
    if (!occurs(key, r.firstDay, r.repeat)) continue
    const start = r.minute === null ? null : resolve(Math.floor(r.minute / 60), r.minute % 60, key)
    out.push({ id: `rem-${r.id}`, start, end: null, title: r.title, color: '#F0932B', kind: null, source: 'reminder' })
  }
  return out.sort((a, b) => (a.start ?? -1) - (b.start ?? -1))
}

/**
 * Заливка дня: доли категорий по запланированному времени и время самого раннего дела.
 * Сон в заливку и в «самое раннее» не входит: иначе он закрашивал бы почти весь день.
 */
export function dayFill(entries: CalendarEntry[]) {
  const timed = entries.filter((e) => e.source !== 'reminder' && e.start !== null && e.end !== null && e.kind !== 'sleep')
  const byColor = new Map<string, number>()
  for (const e of timed) byColor.set(e.color, (byColor.get(e.color) ?? 0) + minutesBetween(e.start!, e.end!))
  const parts = [...byColor].map(([color, minutes]) => ({ color, minutes })).filter((p) => p.minutes > 0).sort((a, b) => b.minutes - a.minutes)
  const total = parts.reduce((a, p) => a + p.minutes, 0)
  const earliest = entries.filter((e) => e.start !== null && e.kind !== 'sleep').map((e) => e.start!).sort((a, b) => a - b)[0] ?? null
  return { parts, total, earliest }
}

/** CSS-фон с полосами категорий слева направо пропорционально времени. */
export function fillBackground(parts: { color: string; minutes: number }[]): string | undefined {
  const total = parts.reduce((a, p) => a + p.minutes, 0)
  if (!total) return undefined
  let acc = 0
  const stops = parts.map((p) => {
    const from = (acc / total) * 100
    acc += p.minutes
    const to = (acc / total) * 100
    return `${p.color} ${from.toFixed(2)}% ${to.toFixed(2)}%`
  })
  return `linear-gradient(to right, ${stops.join(', ')})`
}
