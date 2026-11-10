import DayTrackCore
import Foundation

/// Итоги дня, посчитанные из его записей: сравнение с действующим планом
/// и, если план менялся после фиксации, с исходным.
struct DaySummary {
    /// Сравнение с действующим планом (с учётом правок).
    let current: DayComparison
    /// Сравнение с исходным планом. `nil`, если план не зафиксирован.
    let baseline: DayComparison?
    /// План менялся после фиксации.
    let planWasEdited: Bool

    init(day: Day?, now: Date) {
        guard let day else {
            current = .empty
            baseline = nil
            planWasEdited = false
            return
        }

        let facts = day.facts.map {
            FactSlot(id: $0.uuid, planID: $0.block?.uuid, start: $0.start, end: $0.end)
        }
        let currentPlan = day.activeBlocks.map {
            PlanSlot(id: $0.uuid, start: $0.start, end: $0.end, markedMissed: $0.missReasonRaw != nil)
        }
        current = PlanComparison.evaluate(plan: currentPlan, facts: facts, now: now)

        if day.isLocked {
            let baselinePlan: [PlanSlot] = day.blocks.compactMap { block in
                guard let start = block.baselineStart, let end = block.baselineEnd else { return nil }
                return PlanSlot(
                    id: block.uuid, start: start, end: end,
                    markedMissed: block.missReasonRaw != nil || block.removedAt != nil
                )
            }
            baseline = PlanComparison.evaluate(plan: baselinePlan, facts: facts, now: now)
        } else {
            baseline = nil
        }
        planWasEdited = !day.changes.isEmpty
    }

    func status(of block: PlannedBlock) -> BlockResult? {
        current.result(for: block.uuid)
    }
}
