import type { Day, ID } from './model'
import { activeBlocks, category, getState, kindOf, summary, effectiveFocus } from './store'
import { DayKey, fmtWeekdayShort, minutesBetween } from '../core/time'
import { daysIn, PeriodKind } from '../core/periods'
import { averageByHour, estimateRatios, minutesByCategory, minutesByKind, reasonCounts, StatsBlock, StatsFact } from '../core/stats'
import { CategoryKind, groupOf, BalanceGroup, Reason } from '../core/kinds'

export interface DayPoint {
  key: DayKey; label: string; completion: number | null; planned: number; credited: number
  fact: number; unplanned: number; byKind: Partial<Record<CategoryKind, number>>
}
export interface CategoryLine { id: string; name: string; color: string; planned: number; fact: number; ratio: number | null }

export interface PeriodData {
  range: [DayKey, DayKey]
  days: DayPoint[]
  categories: CategoryLine[]
  byKind: Partial<Record<CategoryKind, number>>
  reasons: { reason: Reason; count: number }[]
  energyByHour: Map<number, number>
  moodByHour: Map<number, number>
  completion: number | null
  totalFact: number
  bestEnergyHours: number[]
}

export function groupMinutes(byKind: Partial<Record<CategoryKind, number>>): Record<BalanceGroup, number> {
  const r: Record<BalanceGroup, number> = { study: 0, rest: 0, sleep: 0, other: 0 }
  for (const [k, v] of Object.entries(byKind)) r[groupOf(k as CategoryKind)] += v ?? 0
  return r
}

export function periodData(range: [DayKey, DayKey], kind: PeriodKind, now = Date.now()): PeriodData {
  const st = getState()
  const allFacts: StatsFact[] = [], allBlocks: StatsBlock[] = [], missed: StatsBlock[] = []
  const days = daysIn(range).map((key): DayPoint => {
    const d: Day | undefined = st.days[key]
    const s = summary(d, now)
    const facts = (d?.facts ?? []).map((f): StatsFact => ({ start: f.start, end: f.end, categoryId: f.categoryId, kind: kindOf(f.categoryId), planId: f.blockId, reason: f.reason, focusId: d ? effectiveFocus(d, f) : null }))
    const blocks = activeBlocks(d).map((b): StatsBlock => ({ id: b.id, start: b.start, end: b.end, categoryId: b.categoryId, kind: kindOf(b.categoryId), missReason: b.missReason, focusId: b.focusId }))
    allFacts.push(...facts); allBlocks.push(...blocks)
    missed.push(...blocks.filter((b) => s.status(b.id)?.status === 'missed'))
    return {
      key, label: kind === 'week' ? fmtWeekdayShort(key) : String(key % 100), completion: s.current.completion,
      planned: s.current.plannedMinutes, credited: s.current.creditedMinutes,
      fact: facts.reduce((a, f) => a + minutesBetween(f.start, f.end), 0), unplanned: s.current.unplannedMinutes, byKind: minutesByKind(facts),
    }
  })
  const factBy = minutesByCategory(allFacts), planBy = minutesByCategory(allBlocks), ratios = estimateRatios(allBlocks, allFacts)
  const ids = new Set<string | null>([...factBy.keys(), ...planBy.keys()])
  const categories = [...ids].map((id): CategoryLine => {
    const c = category(id as ID)
    return { id: id ?? 'none', name: c?.name ?? 'Без категории', color: c?.color ?? '#95A5A6', planned: planBy.get(id) ?? 0, fact: factBy.get(id) ?? 0, ratio: ratios.get(id)?.ratio ?? null }
  }).sort((a, b) => Math.max(b.fact, b.planned) - Math.max(a.fact, a.planned))
  const marks = st.energy.filter((m) => m.day >= range[0] && m.day <= range[1])
  const energyByHour = averageByHour(marks.map((m) => ({ at: m.at, value: m.energy })))
  const moodByHour = averageByHour(marks.map((m) => ({ at: m.at, value: m.mood })))
  const planned = days.reduce((a, d) => a + d.planned, 0)
  let bestEnergyHours: number[] = []
  if (energyByHour.size >= 3) {
    const top = Math.max(...energyByHour.values())
    bestEnergyHours = [...energyByHour].filter(([, v]) => v >= top - 0.25).map(([h]) => h).sort((a, b) => a - b)
  }
  return {
    range, days, categories, byKind: minutesByKind(allFacts), reasons: reasonCounts(allFacts, missed),
    energyByHour, moodByHour, completion: planned > 0 ? days.reduce((a, d) => a + d.credited, 0) / planned : null,
    totalFact: days.reduce((a, d) => a + d.fact, 0), bestEnergyHours,
  }
}

export function heat(completion: number): string {
  const v = Math.min(Math.max(completion, 0), 1)
  if (v < 0.4) return `rgba(235, 77, 75, ${0.25 + v})`
  if (v < 0.7) return `rgba(240, 147, 43, ${0.35 + (v - 0.4)})`
  return `rgba(106, 176, 76, ${0.3 + (v - 0.7) * 1.5})`
}
