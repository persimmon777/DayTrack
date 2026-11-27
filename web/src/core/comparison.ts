import { minutesBetween } from './time'

export interface PlanSlot { id: string; start: number; end: number; markedMissed?: boolean }
export interface FactSlot { id: string; planId?: string | null; start: number; end: number }

export type BlockStatus = 'done' | 'partial' | 'missed' | 'pending'

export interface BlockResult {
  id: string
  plannedMinutes: number
  factMinutes: number
  creditedMinutes: number
  status: BlockStatus
  startShiftMinutes: number | null
  isShifted: boolean
}

export interface DayComparison {
  blocks: BlockResult[]
  plannedMinutes: number
  creditedMinutes: number
  unplannedMinutes: number
  completion: number | null
}

export const doneThreshold = 0.9
export const shiftThreshold = 15

export const emptyComparison: DayComparison = { blocks: [], plannedMinutes: 0, creditedMinutes: 0, unplannedMinutes: 0, completion: null }

export function evaluate(plan: PlanSlot[], facts: FactSlot[], now: number): DayComparison {
  const ids = new Set(plan.map((p) => p.id))
  const byPlan = new Map<string, FactSlot[]>()
  let unplanned = 0
  for (const fact of facts) {
    if (fact.planId && ids.has(fact.planId)) {
      const list = byPlan.get(fact.planId) ?? []
      list.push(fact)
      byPlan.set(fact.planId, list)
    } else {
      unplanned += minutesBetween(fact.start, fact.end)
    }
  }
  const blocks = plan.map((slot): BlockResult => {
    const planned = minutesBetween(slot.start, slot.end)
    const linked = byPlan.get(slot.id) ?? []
    const factMinutes = linked.reduce((s, f) => s + minutesBetween(f.start, f.end), 0)
    const credited = Math.min(factMinutes, planned)
    let status: BlockStatus
    if (factMinutes > 0) status = planned === 0 || credited >= planned * doneThreshold ? 'done' : 'partial'
    else if (slot.markedMissed || slot.end <= now) status = 'missed'
    else status = 'pending'
    const firstStart = linked.length ? Math.min(...linked.map((f) => f.start)) : null
    const shift = firstStart === null ? null : Math.round((firstStart - slot.start) / 60000)
    return {
      id: slot.id, plannedMinutes: planned, factMinutes, creditedMinutes: credited, status,
      startShiftMinutes: shift, isShifted: shift !== null && Math.abs(shift) > shiftThreshold,
    }
  })
  const plannedMinutes = blocks.reduce((s, b) => s + b.plannedMinutes, 0)
  const creditedMinutes = blocks.reduce((s, b) => s + b.creditedMinutes, 0)
  return { blocks, plannedMinutes, creditedMinutes, unplannedMinutes: unplanned, completion: plannedMinutes > 0 ? creditedMinutes / plannedMinutes : null }
}

/** Раскладка пересекающихся блоков по колонкам. */
export function layout(spans: { start: number; end: number }[]): { column: number; columnCount: number }[] {
  const slots = spans.map(() => ({ column: 0, columnCount: 1 }))
  const order = spans.map((_, i) => i).sort((a, b) =>
    spans[a].start !== spans[b].start ? spans[a].start - spans[b].start
      : spans[a].end !== spans[b].end ? spans[b].end - spans[a].end : a - b)
  let group: number[] = []
  let columnEnds: number[] = []
  let groupEnd = -Infinity
  const close = () => {
    for (const i of group) slots[i].columnCount = Math.max(columnEnds.length, 1)
    group = []
    columnEnds = []
  }
  for (const i of order) {
    const span = { start: spans[i].start, end: Math.max(spans[i].end, spans[i].start) }
    if (group.length && span.start >= groupEnd) { close(); groupEnd = -Infinity }
    const free = columnEnds.findIndex((end) => end <= span.start)
    if (free >= 0) { columnEnds[free] = span.end; slots[i].column = free }
    else { columnEnds.push(span.end); slots[i].column = columnEnds.length - 1 }
    group.push(i)
    groupEnd = Math.max(groupEnd, span.end)
  }
  close()
  return slots
}
