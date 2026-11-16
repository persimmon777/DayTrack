import DayTrackCore
import Foundation
import SwiftData
import WidgetKit

/// Цель баланса на один день.
enum BalanceTarget {
    private static let defaults = UserDefaults.standard

    static var studyMinutes: Int {
        get { value("target.study", 360) }
        set { defaults.set(newValue, forKey: "target.study") }
    }
    static var restMinutes: Int {
        get { value("target.rest", 180) }
        set { defaults.set(newValue, forKey: "target.rest") }
    }
    static var sleepMinutes: Int {
        get { value("target.sleep", 480) }
        set { defaults.set(newValue, forKey: "target.sleep") }
    }

    private static func value(_ key: String, _ fallback: Int) -> Int {
        let stored = defaults.integer(forKey: key)
        return stored > 0 ? stored : fallback
    }
}

/// Передаёт виджету баланс за сегодня и неделю.
@MainActor
enum WidgetSync {
    static func refresh(context: ModelContext) {
        let calendar = Calendar.current
        let todayKey = DayClock.app.key(for: .now)
        let week = Periods.range(.week, containing: todayKey, calendar: calendar)
        let from = week.lowerBound, to = week.upperBound
        let days = (try? context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.key >= from && $0.key <= to }))) ?? []

        var today = BalanceMinutes()
        var weekTotal = BalanceMinutes()
        for day in days {
            for fact in day.facts {
                let minutes = PlanComparison.minutes(from: fact.start, to: fact.end)
                add(minutes, kind: fact.category?.kind ?? .other, to: &weekTotal)
                if day.key == todayKey { add(minutes, kind: fact.category?.kind ?? .other, to: &today) }
            }
        }

        let elapsed = Periods.days(in: week.lowerBound...todayKey, calendar: calendar).count
        WidgetSnapshotStore.write(WidgetSnapshot(
            writtenAt: .now,
            dayKey: todayKey,
            today: today,
            week: weekTotal,
            weekDaysElapsed: elapsed,
            target: BalanceMinutes(
                study: BalanceTarget.studyMinutes,
                rest: BalanceTarget.restMinutes,
                sleep: BalanceTarget.sleepMinutes
            )
        ))
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.widgetKind)
    }

    private static func add(_ minutes: Int, kind: CategoryKind, to balance: inout BalanceMinutes) {
        switch kind {
        case .study: balance.study += minutes
        case .rest: balance.rest += minutes
        case .sleep: balance.sleep += minutes
        default: balance.other += minutes
        }
    }
}
