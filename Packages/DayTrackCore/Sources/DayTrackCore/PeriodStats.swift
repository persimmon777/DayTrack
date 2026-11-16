import Foundation

/// Запись факта для статистики.
public struct StatsFact: Equatable, Sendable {
    public var start: Date
    public var end: Date
    /// Идентификатор категории (любая строка) или `nil`, если категории нет.
    public var categoryID: String?
    public var kind: CategoryKind
    public var planID: UUID?
    public var reason: DeviationReason?
    public var focusID: UUID?

    public init(start: Date, end: Date, categoryID: String?, kind: CategoryKind,
                planID: UUID? = nil, reason: DeviationReason? = nil, focusID: UUID? = nil) {
        self.start = start
        self.end = end
        self.categoryID = categoryID
        self.kind = kind
        self.planID = planID
        self.reason = reason
        self.focusID = focusID
    }

    public var minutes: Int { PlanComparison.minutes(from: start, to: end) }
}

/// Блок плана для статистики.
public struct StatsBlock: Equatable, Sendable {
    public var id: UUID
    public var start: Date
    public var end: Date
    public var categoryID: String?
    public var kind: CategoryKind
    public var missReason: DeviationReason?
    public var focusID: UUID?

    public init(id: UUID, start: Date, end: Date, categoryID: String?, kind: CategoryKind,
                missReason: DeviationReason? = nil, focusID: UUID? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.categoryID = categoryID
        self.kind = kind
        self.missReason = missReason
        self.focusID = focusID
    }

    public var minutes: Int { PlanComparison.minutes(from: start, to: end) }
}

public enum PeriodStats {
    /// Минуты по типам категорий.
    public static func minutesByKind(_ facts: [StatsFact]) -> [CategoryKind: Int] {
        facts.reduce(into: [:]) { $0[$1.kind, default: 0] += $1.minutes }
    }

    /// Минуты по категориям (ключ `nil` — без категории).
    public static func minutesByCategory(_ facts: [StatsFact]) -> [String?: Int] {
        facts.reduce(into: [:]) { $0[$1.categoryID, default: 0] += $1.minutes }
    }

    /// Минуты плана по категориям.
    public static func plannedByCategory(_ blocks: [StatsBlock]) -> [String?: Int] {
        blocks.reduce(into: [:]) { $0[$1.categoryID, default: 0] += $1.minutes }
    }

    /// Как часто встречалась каждая причина: у дел вне плана и у несделанных блоков.
    /// По убыванию, при равенстве — в порядке списка причин.
    public static func reasonCounts(facts: [StatsFact], missedBlocks: [StatsBlock]) -> [(reason: DeviationReason, count: Int)] {
        var counts: [DeviationReason: Int] = [:]
        for fact in facts where fact.planID == nil {
            counts[fact.reason ?? .other, default: 0] += 1
        }
        for block in missedBlocks {
            counts[block.missReason ?? .other, default: 0] += 1
        }
        return DeviationReason.allCases
            .compactMap { reason in counts[reason].map { (reason: reason, count: $0) } }
            .sorted { $0.count > $1.count }
    }

    /// Средняя отметка по часам суток (0–23).
    public static func averageByHour(_ marks: [(date: Date, value: Int)], calendar: Calendar) -> [Int: Double] {
        var sums: [Int: (total: Int, count: Int)] = [:]
        for mark in marks {
            let hour = calendar.component(.hour, from: mark.date)
            let current = sums[hour] ?? (0, 0)
            sums[hour] = (current.total + mark.value, current.count + 1)
        }
        return sums.mapValues { Double($0.total) / Double($0.count) }
    }

    /// Во сколько раз факт длиннее плана по категориям: медиана отношений
    /// по блокам, у которых есть факт. Например, 1.3 — на 30% дольше плана.
    public static func estimateRatios(blocks: [StatsBlock], facts: [StatsFact]) -> [String?: Double] {
        var factByPlan: [UUID: Int] = [:]
        for fact in facts {
            guard let planID = fact.planID else { continue }
            factByPlan[planID, default: 0] += fact.minutes
        }
        var ratios: [String?: [Double]] = [:]
        for block in blocks where block.minutes > 0 {
            guard let fact = factByPlan[block.id], fact > 0 else { continue }
            ratios[block.categoryID, default: []].append(Double(fact) / Double(block.minutes))
        }
        return ratios.mapValues(median)
    }

    public static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// Минуты факта по фокусам. Запись без своего фокуса берёт фокус блока плана.
    /// `parentOf` даёт месячный фокус для недельного: его минуты идут и в месячный.
    public static func focusMinutes(
        facts: [StatsFact], blockFocus: [UUID: UUID], parentOf: [UUID: UUID]
    ) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        for fact in facts {
            guard let focus = fact.focusID ?? fact.planID.flatMap({ blockFocus[$0] }) else { continue }
            result[focus, default: 0] += fact.minutes
            if let parent = parentOf[focus] { result[parent, default: 0] += fact.minutes }
        }
        return result
    }
}
