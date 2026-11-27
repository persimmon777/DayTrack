import { CategoryKind, Reason, reasons } from './kinds'
import { addDays, DayKey, minutesBetween } from './time'
import { weekStart } from './periods'

export interface StatsFact { start: number; end: number; categoryId: string | null; kind: CategoryKind; planId?: string | null; reason?: Reason | null; focusId?: string | null }
export interface StatsBlock { id: string; start: number; end: number; categoryId: string | null; kind: CategoryKind; missReason?: Reason | null; focusId?: string | null }

const mins = (x: { start: number; end: number }) => minutesBetween(x.start, x.end)

export function minutesByKind(facts: StatsFact[]): Partial<Record<CategoryKind, number>> {
  const r: Partial<Record<CategoryKind, number>> = {}
  for (const f of facts) r[f.kind] = (r[f.kind] ?? 0) + mins(f)
  return r
}

export function minutesByCategory(items: { start: number; end: number; categoryId: string | null }[]): Map<string | null, number> {
  const r = new Map<string | null, number>()
  for (const f of items) r.set(f.categoryId, (r.get(f.categoryId) ?? 0) + mins(f))
  return r
}

export function reasonCounts(facts: StatsFact[], missed: StatsBlock[]): { reason: Reason; count: number }[] {
  const c = new Map<Reason, number>()
  for (const f of facts) if (!f.planId) c.set(f.reason ?? 'other', (c.get(f.reason ?? 'other') ?? 0) + 1)
  for (const b of missed) c.set(b.missReason ?? 'other', (c.get(b.missReason ?? 'other') ?? 0) + 1)
  return reasons.filter((r) => c.has(r.id)).map((r) => ({ reason: r.id, count: c.get(r.id)! }))
    .sort((a, b) => b.count - a.count)
}

export function averageByHour(marks: { at: number; value: number }[]): Map<number, number> {
  const sums = new Map<number, [number, number]>()
  for (const m of marks) {
    const h = new Date(m.at).getHours()
    const [t, c] = sums.get(h) ?? [0, 0]
    sums.set(h, [t + m.value, c + 1])
  }
  const r = new Map<number, number>()
  sums.forEach(([t, c], h) => r.set(h, t / c))
  return r
}

export function median(values: number[]): number {
  const s = [...values].sort((a, b) => a - b)
  if (!s.length) return 0
  const mid = Math.floor(s.length / 2)
  return s.length % 2 === 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid]
}

export function estimateRatios(blocks: StatsBlock[], facts: StatsFact[]): Map<string | null, { ratio: number; samples: number }> {
  const byPlan = new Map<string, number>()
  for (const f of facts) if (f.planId) byPlan.set(f.planId, (byPlan.get(f.planId) ?? 0) + mins(f))
  const ratios = new Map<string | null, number[]>()
  for (const b of blocks) {
    const planned = mins(b), fact = byPlan.get(b.id) ?? 0
    if (planned <= 0 || fact <= 0) continue
    const list = ratios.get(b.categoryId) ?? []
    list.push(fact / planned)
    ratios.set(b.categoryId, list)
  }
  const r = new Map<string | null, { ratio: number; samples: number }>()
  ratios.forEach((list, id) => r.set(id, { ratio: median(list), samples: list.length }))
  return r
}

// MARK: Мягкие серии

/** День засчитывается, если в нём есть план и вечерний разбор. Один пропуск в неделю прощается. */
export function softStreak(done: Set<DayKey>, today: DayKey): number {
  let streak = 0, pending = 0
  const misses = new Map<DayKey, number>()
  let key = done.has(today) ? today : addDays(today, -1)
  for (let i = 0; i < 800; i++) {
    if (done.has(key)) { streak += 1 + pending; pending = 0 }
    else {
      const w = weekStart(key)
      const n = (misses.get(w) ?? 0) + 1
      misses.set(w, n)
      if (n > 1) break
      pending += 1
    }
    key = addDays(key, -1)
  }
  return streak
}

export function countLastDays(done: Set<DayKey>, days: number, today: DayKey): number {
  let n = 0
  for (let i = 0; i < days; i++) if (done.has(addDays(today, -i))) n++
  return n
}
