import DayTrackCore
import Foundation
import SwiftUI

/// Всё, что нужно графикам и отчёту за период, посчитанное один раз.
struct PeriodAnalytics {
    struct DayPoint: Identifiable {
        var key: Int
        var label: String
        var completion: Double?
        var plannedMinutes: Int
        var creditedMinutes: Int
        var factMinutes: Int
        var unplannedMinutes: Int
        var byKind: [CategoryKind: Int]
        var hasPlan: Bool { plannedMinutes > 0 }
        var hasFact: Bool { factMinutes > 0 }
        var id: Int { key }
    }

    struct CategoryLine: Identifiable {
        var id: String
        var name: String
        var color: Color
        var planned: Int
        var fact: Int
        /// Во сколько раз факт по блокам этой категории длиннее плана.
        var estimateRatio: Double?
    }

    var range: ClosedRange<Int>
    var days: [DayPoint]
    var categories: [CategoryLine]
    var byKind: [CategoryKind: Int]
    var reasons: [(reason: DeviationReason, count: Int)]
    var energyByHour: [Int: Double]
    var moodByHour: [Int: Double]

    var daysWithPlan: [DayPoint] { days.filter(\.hasPlan) }

    /// Выполнение плана по всем дням с планом вместе.
    var completion: Double? {
        let planned = days.reduce(0) { $0 + $1.plannedMinutes }
        guard planned > 0 else { return nil }
        return Double(days.reduce(0) { $0 + $1.creditedMinutes }) / Double(planned)
    }

    var totalFactMinutes: Int { days.reduce(0) { $0 + $1.factMinutes } }

    /// Часы с самой высокой средней энергией.
    var bestEnergyHours: [Int] {
        guard energyByHour.count >= 3 else { return [] }
        let top = energyByHour.values.max() ?? 0
        return energyByHour.filter { $0.value >= top - 0.25 }.keys.sorted()
    }

    init(range: ClosedRange<Int>, kind: PeriodKind, days dayModels: [Day], marks: [EnergyMark], now: Date = .now) {
        let calendar = Calendar.current
        self.range = range
        let byKey = Dictionary(dayModels.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })

        var allFacts: [StatsFact] = []
        var allBlocks: [StatsBlock] = []
        var missed: [StatsBlock] = []
        var names: [String: (String, Color)] = [:]
        var points: [DayPoint] = []

        for key in Periods.days(in: range, calendar: calendar) {
            let day = byKey[key]
            let comparison = DaySummary(day: day, now: now).current
            let facts = (day?.facts ?? []).map { fact -> StatsFact in
                if let category = fact.category {
                    names[category.uuid.uuidString] = (category.name, Color(hex: category.colorHex))
                }
                return StatsFact(
                    start: fact.start, end: fact.end,
                    categoryID: fact.category?.uuid.uuidString,
                    kind: fact.category?.kind ?? .other,
                    planID: fact.block?.uuid, reason: fact.reason,
                    focusID: fact.effectiveFocusUUID
                )
            }
            let blocks = (day?.activeBlocks ?? []).map { block -> StatsBlock in
                if let category = block.category {
                    names[category.uuid.uuidString] = (category.name, Color(hex: category.colorHex))
                }
                return StatsBlock(
                    id: block.uuid, start: block.start, end: block.end,
                    categoryID: block.category?.uuid.uuidString,
                    kind: block.category?.kind ?? .other,
                    missReason: block.missReason, focusID: block.focusUUID
                )
            }
            allFacts += facts
            allBlocks += blocks
            missed += blocks.filter { comparison.result(for: $0.id)?.status == .missed }

            points.append(DayPoint(
                key: key,
                label: Self.label(for: key, kind: kind, calendar: calendar),
                completion: comparison.completion,
                plannedMinutes: comparison.plannedMinutes,
                creditedMinutes: comparison.creditedMinutes,
                factMinutes: facts.reduce(0) { $0 + $1.minutes },
                unplannedMinutes: comparison.unplannedMinutes,
                byKind: PeriodStats.minutesByKind(facts)
            ))
        }

        days = points
        byKind = PeriodStats.minutesByKind(allFacts)
        reasons = PeriodStats.reasonCounts(facts: allFacts, missedBlocks: missed)

        let factByCategory = PeriodStats.minutesByCategory(allFacts)
        let planByCategory = PeriodStats.plannedByCategory(allBlocks)
        let ratios = PeriodStats.estimateRatios(blocks: allBlocks, facts: allFacts)
        let ids = Set(factByCategory.keys).union(planByCategory.keys)
        categories = ids.map { id in
            let info = id.flatMap { names[$0] }
            return CategoryLine(
                id: id ?? "none",
                name: info?.0 ?? "Без категории",
                color: info?.1 ?? .gray,
                planned: planByCategory[id] ?? 0,
                fact: factByCategory[id] ?? 0,
                estimateRatio: ratios[id]
            )
        }
        .sorted { max($0.fact, $0.planned) > max($1.fact, $1.planned) }

        energyByHour = PeriodStats.averageByHour(marks.map { ($0.at, $0.energy) }, calendar: calendar)
        moodByHour = PeriodStats.averageByHour(marks.map { ($0.at, $0.mood) }, calendar: calendar)
    }

    static func label(for key: Int, kind: PeriodKind, calendar: Calendar) -> String {
        guard let date = Recurrence.date(forKey: key, calendar: calendar) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Format.locale
        formatter.dateFormat = kind == .week ? "EEEEEE" : "d"
        return formatter.string(from: date)
    }
}

/// Группы для графика баланса.
enum BalanceGroup: String, CaseIterable {
    case study = "Учёба"
    case rest = "Отдых"
    case sleep = "Сон"
    case other = "Прочее"

    static func of(_ kind: CategoryKind) -> BalanceGroup {
        switch kind {
        case .study: return .study
        case .rest: return .rest
        case .sleep: return .sleep
        default: return .other
        }
    }

    var color: Color {
        switch self {
        case .study: return Color(hex: "6C5CE7")
        case .rest: return Color(hex: "6AB04C")
        case .sleep: return Color(hex: "3C6382")
        case .other: return Color(hex: "B2BEC3")
        }
    }

    static func minutes(_ byKind: [CategoryKind: Int]) -> [BalanceGroup: Int] {
        byKind.reduce(into: [:]) { $0[of($1.key), default: 0] += $1.value }
    }
}
