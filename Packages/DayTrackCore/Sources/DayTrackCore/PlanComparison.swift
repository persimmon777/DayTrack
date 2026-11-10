import Foundation

/// Блок плана в виде, нужном для сравнения.
public struct PlanSlot: Equatable, Sendable {
    public var id: UUID
    public var start: Date
    public var end: Date
    /// Пользователь сам отметил блок как несделанный.
    public var markedMissed: Bool

    public init(id: UUID, start: Date, end: Date, markedMissed: Bool = false) {
        self.id = id
        self.start = start
        self.end = end
        self.markedMissed = markedMissed
    }
}

/// Запись факта. `planID == nil` означает дело вне плана.
public struct FactSlot: Equatable, Sendable {
    public var id: UUID
    public var planID: UUID?
    public var start: Date
    public var end: Date

    public init(id: UUID, planID: UUID?, start: Date, end: Date) {
        self.id = id
        self.planID = planID
        self.start = start
        self.end = end
    }
}

public enum BlockStatus: String, Sendable {
    /// Факт покрывает почти всё запланированное время.
    case done
    /// Факт есть, но меньше плана.
    case partial
    /// Время блока прошло, факта нет (или блок отмечен несделанным).
    case missed
    /// Время блока ещё не прошло, факта пока нет.
    case pending
}

public struct BlockResult: Equatable, Sendable {
    public var id: UUID
    public var plannedMinutes: Int
    /// Сколько минут факта внесено по этому блоку.
    public var factMinutes: Int
    /// Сколько из них засчитано в выполнение: не больше запланированного.
    public var creditedMinutes: Int
    public var status: BlockStatus
    /// На сколько минут начало факта отличается от плана. Положительное — позже.
    public var startShiftMinutes: Int?
    /// Начало сдвинуто больше допустимого.
    public var isShifted: Bool
}

public struct DayComparison: Equatable, Sendable {
    public var blocks: [BlockResult]
    public var plannedMinutes: Int
    public var creditedMinutes: Int
    /// Минуты дел вне плана.
    public var unplannedMinutes: Int

    /// Доля выполнения плана от 0 до 1. `nil`, если в плане нет времени.
    public var completion: Double? {
        plannedMinutes > 0 ? Double(creditedMinutes) / Double(plannedMinutes) : nil
    }

    public func result(for id: UUID) -> BlockResult? {
        blocks.first { $0.id == id }
    }

    public func count(of status: BlockStatus) -> Int {
        blocks.filter { $0.status == status }.count
    }
}

public enum PlanComparison {
    /// Доля плана, начиная с которой блок считается выполненным.
    public static let doneThreshold = 0.9
    /// Сдвиг начала в минутах, начиная с которого блок считается сдвинутым.
    public static let shiftThresholdMinutes = 15

    public static func minutes(from start: Date, to end: Date) -> Int {
        max(0, Int((end.timeIntervalSince(start) / 60).rounded()))
    }

    /// Сравнивает план с фактом.
    ///
    /// Факты, привязанные к блоку, которого нет в `plan` (например, удалённому
    /// после фиксации), считаются делами вне плана.
    public static func evaluate(plan: [PlanSlot], facts: [FactSlot], now: Date) -> DayComparison {
        let planIDs = Set(plan.map(\.id))
        var factsByPlan: [UUID: [FactSlot]] = [:]
        var unplannedMinutes = 0

        for fact in facts {
            if let planID = fact.planID, planIDs.contains(planID) {
                factsByPlan[planID, default: []].append(fact)
            } else {
                unplannedMinutes += minutes(from: fact.start, to: fact.end)
            }
        }

        let results = plan.map { slot -> BlockResult in
            let planned = minutes(from: slot.start, to: slot.end)
            let linked = factsByPlan[slot.id] ?? []
            let factMinutes = linked.reduce(0) { $0 + minutes(from: $1.start, to: $1.end) }
            let credited = min(factMinutes, planned)

            let status: BlockStatus
            if factMinutes > 0 {
                let isDone = planned == 0 || Double(credited) >= Double(planned) * doneThreshold
                status = isDone ? .done : .partial
            } else if slot.markedMissed || slot.end <= now {
                status = .missed
            } else {
                status = .pending
            }

            let shift = linked.map(\.start).min().map { firstStart in
                Int((firstStart.timeIntervalSince(slot.start) / 60).rounded())
            }

            return BlockResult(
                id: slot.id,
                plannedMinutes: planned,
                factMinutes: factMinutes,
                creditedMinutes: credited,
                status: status,
                startShiftMinutes: shift,
                isShifted: shift.map { abs($0) > shiftThresholdMinutes } ?? false
            )
        }

        return DayComparison(
            blocks: results,
            plannedMinutes: results.reduce(0) { $0 + $1.plannedMinutes },
            creditedMinutes: results.reduce(0) { $0 + $1.creditedMinutes },
            unplannedMinutes: unplannedMinutes
        )
    }
}
