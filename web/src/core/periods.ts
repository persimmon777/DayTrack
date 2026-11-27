import { addDays, daysInMonth, DayKey, noonOfKey, partsOf, weekday } from './time'

export type RepeatRule = 'none' | 'weekly' | 'monthly' | 'yearly'
export const repeatRules: { id: RepeatRule; title: string }[] = [
  { id: 'none', title: 'Не повторять' },
  { id: 'weekly', title: 'Каждую неделю' },
  { id: 'monthly', title: 'Каждый месяц' },
  { id: 'yearly', title: 'Каждый год' },
]

export function occurs(key: DayKey, first: DayKey, rule: RepeatRule): boolean {
  if (key < first) return false
  const t = partsOf(key), s = partsOf(first)
  switch (rule) {
    case 'none': return key === first
    case 'weekly': return weekday(key) === weekday(first)
    case 'monthly': return t.day === Math.min(s.day, daysInMonth(t.year, t.month))
    case 'yearly': return t.month === s.month && t.day === Math.min(s.day, daysInMonth(t.year, t.month))
  }
}

export function occurrences(first: DayKey, rule: RepeatRule, from: DayKey, through: DayKey): DayKey[] {
  const result: DayKey[] = []
  let key = from
  for (let i = 0; i < 731 && key <= through; i++) {
    if (occurs(key, first, rule)) result.push(key)
    key = addDays(key, 1)
  }
  return result
}

// MARK: Периоды

export type PeriodKind = 'day' | 'week' | 'month'
export const periodKinds: { id: PeriodKind; title: string }[] = [
  { id: 'day', title: 'День' }, { id: 'week', title: 'Неделя' }, { id: 'month', title: 'Месяц' },
]

export function weekStart(key: DayKey): DayKey {
  const shift = (noonOfKey(key).getDay() + 6) % 7
  return addDays(key, -shift)
}

export function periodRange(kind: PeriodKind, key: DayKey): [DayKey, DayKey] {
  if (kind === 'day') return [key, key]
  if (kind === 'week') { const s = weekStart(key); return [s, addDays(s, 6)] }
  const { year, month } = partsOf(key)
  const first = year * 10000 + month * 100 + 1
  return [first, first + daysInMonth(year, month) - 1]
}

export function shiftPeriod(key: DayKey, kind: PeriodKind, steps: number): DayKey {
  if (kind === 'day') return addDays(key, steps)
  if (kind === 'week') return addDays(key, 7 * steps)
  const { year, month, day } = partsOf(key)
  const m0 = month - 1 + steps
  const y = year + Math.floor(m0 / 12)
  const m = ((m0 % 12) + 12) % 12 + 1
  return y * 10000 + m * 100 + Math.min(day, daysInMonth(y, m))
}

export function daysIn([from, to]: [DayKey, DayKey]): DayKey[] {
  const result: DayKey[] = []
  let key = from
  while (key <= to && result.length < 400) { result.push(key); key = addDays(key, 1) }
  return result
}

// MARK: Расписание с чётностью недель

export type WeekParity = 'every' | 'odd' | 'even'
export const parities: { id: WeekParity; title: string }[] = [
  { id: 'every', title: 'Каждую неделю' }, { id: 'odd', title: 'По нечётным' }, { id: 'even', title: 'По чётным' },
]

export interface RuleData { weekday: number; parity: WeekParity; validFrom?: DayKey | null; validUntil?: DayKey | null; enabled: boolean }

export function weekNumber(key: DayKey, firstWeekKey: DayKey): number {
  const a = noonOfKey(weekStart(key)).getTime()
  const b = noonOfKey(weekStart(firstWeekKey)).getTime()
  return Math.floor(Math.round((a - b) / 86400000) / 7) + 1
}

export function ruleApplies(rule: RuleData, key: DayKey, firstWeekKey: DayKey): boolean {
  if (!rule.enabled) return false
  if (rule.validFrom && key < rule.validFrom) return false
  if (rule.validUntil && key > rule.validUntil) return false
  if (weekday(key) !== rule.weekday) return false
  if (rule.parity === 'every') return true
  const odd = Math.abs(weekNumber(key, firstWeekKey)) % 2 === 1
  return rule.parity === 'odd' ? odd : !odd
}

export function defaultFirstWeekKey(today: DayKey): DayKey {
  const { year, month } = partsOf(today)
  return (month >= 9 ? year : year - 1) * 10000 + 901
}
