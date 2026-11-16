import DayTrackCore
import Foundation
import SwiftData

/// Подъём и отбой из первого запуска.
enum UserProfile {
    private static let defaults = UserDefaults.standard

    static var wakeMinute: Int {
        get { defaults.object(forKey: "profile.wake") as? Int ?? 8 * 60 }
        set { defaults.set(newValue, forKey: "profile.wake") }
    }
    static var bedMinute: Int {
        get { defaults.object(forKey: "profile.bed") as? Int ?? 24 * 60 }
        set { defaults.set(newValue, forKey: "profile.bed") }
    }

    /// Минуты бодрствования между подъёмом и отбоем.
    static var awakeMinutes: Int {
        let span = (bedMinute - wakeMinute + 24 * 60) % (24 * 60)
        return span == 0 ? 16 * 60 : span
    }
}

/// Пороги и отключённые правила советчика.
enum AdvisorPreferences {
    private static let defaults = UserDefaults.standard

    static var disabled: Set<AdviceRule> {
        get { Set((defaults.stringArray(forKey: "advisor.disabled") ?? []).compactMap(AdviceRule.init(rawValue:))) }
        set { defaults.set(newValue.map(\.rawValue), forKey: "advisor.disabled") }
    }
    static var loadLimitPercent: Int {
        get { defaults.object(forKey: "advisor.load") as? Int ?? 70 }
        set { defaults.set(newValue, forKey: "advisor.load") }
    }
    static var bufferMinutes: Int {
        get { defaults.object(forKey: "advisor.buffer") as? Int ?? 60 }
        set { defaults.set(newValue, forKey: "advisor.buffer") }
    }
    static var studyCeilingMinutes: Int {
        get { defaults.object(forKey: "advisor.ceiling") as? Int ?? 8 * 60 }
        set { defaults.set(newValue, forKey: "advisor.ceiling") }
    }

    static var settings: AdvisorSettings {
        AdvisorSettings(
            loadLimit: Double(loadLimitPercent) / 100,
            bufferMinutes: bufferMinutes,
            breakIntervalMinutes: NotificationSettings.breakInterval,
            studyCeilingMinutes: studyCeilingMinutes,
            minSleepMinutes: 7 * 60,
            studyTargetMinutes: BalanceTarget.studyMinutes,
            disabled: disabled
        )
    }

    private static func dismissedKey(_ dayKey: Int) -> String { "advice.dismissed.\(dayKey)" }

    static func dismissed(for dayKey: Int) -> Set<String> {
        Set(defaults.stringArray(forKey: dismissedKey(dayKey)) ?? [])
    }

    static func dismiss(_ id: String, dayKey: Int) {
        var set = dismissed(for: dayKey)
        set.insert(id)
        defaults.set(Array(set), forKey: dismissedKey(dayKey))
    }
}

/// Собирает данные для советчика и применяет его действия.
@MainActor
struct AdvisorService {
    let context: ModelContext
    private let clock = DayClock.app
    private var calendar: Calendar { clock.calendar }

    private func days(_ range: ClosedRange<Int>) -> [Day] {
        let from = range.lowerBound, to = range.upperBound
        return (try? context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.key >= from && $0.key <= to }))) ?? []
    }

    func advice(for dayKey: Int, now: Date = .now) -> [Advice] {
        guard let window = clock.window(forKey: dayKey) else { return [] }
        let store = DayStore(context: context)
        let day = store.day(forKey: dayKey)

        let blocks = (day?.activeBlocks ?? []).map { block in
            AdvisorBlock(
                id: block.uuid, title: block.title, start: block.start, end: block.end,
                kind: block.category?.kind ?? .other,
                categoryID: block.category?.uuid.uuidString, categoryName: block.category?.name,
                isFrog: block.isFrog, hasFact: !block.facts.isEmpty
            )
        }

        // История за четыре недели до этого дня.
        let historyFrom = clock.key(byAdding: -28, to: dayKey)
        let historyTo = clock.key(byAdding: -1, to: dayKey)
        let history = days(historyFrom...historyTo)
        var ratios: [String: [Double]] = [:]
        for past in history {
            for block in past.activeBlocks {
                guard let id = block.category?.uuid.uuidString else { continue }
                let planned = PlanComparison.minutes(from: block.start, to: block.end)
                let fact = block.facts.reduce(0) { $0 + PlanComparison.minutes(from: $1.start, to: $1.end) }
                guard planned > 0, fact > 0 else { continue }
                ratios[id, default: []].append(Double(fact) / Double(planned))
            }
        }
        let estimateHistory = ratios.mapValues { (ratio: PeriodStats.median($0), samples: $0.count) }

        var daysWithoutPlan = 0
        let byKey = Dictionary(history.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var key = historyTo
        while daysWithoutPlan < 7, (byKey[key]?.activeBlocks.isEmpty ?? true) {
            daysWithoutPlan += 1
            key = clock.key(byAdding: -1, to: key)
        }

        let marksFrom = clock.key(byAdding: -14, to: dayKey)
        let marks = (try? context.fetch(FetchDescriptor<EnergyMark>(
            predicate: #Predicate { $0.dayKey >= marksFrom && $0.dayKey <= dayKey }
        ))) ?? []
        var bestHours: [Int] = []
        if marks.count >= 8, Set(marks.map(\.dayKey)).count >= 5 {
            let averages = PeriodStats.averageByHour(marks.map { ($0.at, $0.energy) }, calendar: calendar)
            if let top = averages.values.max() {
                bestHours = averages.filter { $0.value >= top - 0.25 }.keys.sorted()
            }
        }

        let week = Periods.range(.week, containing: dayKey, calendar: calendar)
        var weekStudy = 0
        var elapsed = 0
        if week.lowerBound < dayKey {
            let weekDays = days(week.lowerBound...clock.key(byAdding: -1, to: dayKey))
            weekStudy = weekDays.flatMap(\.facts)
                .filter { $0.category?.kind == .study }
                .reduce(0) { $0 + PlanComparison.minutes(from: $1.start, to: $1.end) }
            elapsed = Periods.days(in: week.lowerBound...clock.key(byAdding: -1, to: dayKey), calendar: calendar).count
        }

        let input = AdvisorInput(
            blocks: blocks,
            taskEstimates: (day?.tasks ?? []).filter { !$0.isDone }.map(\.estimateMinutes),
            dayWindow: window,
            now: now,
            awakeMinutes: UserProfile.awakeMinutes,
            estimateHistory: estimateHistory,
            daysWithoutPlan: daysWithoutPlan,
            bestEnergyHours: bestHours,
            weekStudyMinutes: weekStudy,
            weekDaysElapsed: elapsed
        )
        let dismissed = AdvisorPreferences.dismissed(for: dayKey)
        return Advisor.advise(input, settings: AdvisorPreferences.settings, calendar: calendar)
            .filter { !dismissed.contains($0.id) }
    }

    func apply(_ action: AdviceAction, dayKey: Int) {
        let store = DayStore(context: context)
        switch action {
        case .markFrog(let id):
            if let block = store.day(forKey: dayKey)?.blocks.first(where: { $0.uuid == id }) {
                store.setFrog(block, true)
            }
        case .extendCategory(let categoryID, let ratio):
            for block in store.day(forKey: dayKey)?.activeBlocks ?? [] where block.category?.uuid.uuidString == categoryID {
                let extra = block.end.timeIntervalSince(block.start) * (ratio - 1)
                let rounded = (extra / 300).rounded() * 300
                store.updateBlock(
                    block, title: block.title, category: block.category,
                    start: block.start, end: block.end.addingTimeInterval(rounded), note: block.note
                )
            }
        case .addBlock(let title, let kind, let start, let minutes):
            let categories = (try? context.fetch(FetchDescriptor<ActivityCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
            let category = categories.first { $0.kind == kind && !$0.isArchived }
            store.addBlock(
                dayKey: dayKey, title: title, category: category,
                start: start, end: start.addingTimeInterval(TimeInterval(minutes * 60)), note: ""
            )
        }
    }

    // MARK: Серии

    /// Длина мягкой серии и число засчитанных дней за 30 дней.
    func streak(today: Int) -> (streak: Int, last30: Int) {
        let from = clock.key(byAdding: -120, to: today)
        let reflections = (try? context.fetch(FetchDescriptor<Reflection>(
            predicate: #Predicate { $0.dayKey >= from && $0.dayKey <= today }
        ))) ?? []
        let reflected = Set(reflections.filter { !$0.isEmpty }.map(\.dayKey))
        let done = Set(days(from...today).filter { !$0.activeBlocks.isEmpty && reflected.contains($0.key) }.map(\.key))
        return (
            Streaks.softStreak(doneKeys: done, today: today, calendar: calendar),
            Streaks.count(doneKeys: done, lastDays: 30, today: today, calendar: calendar)
        )
    }
}
