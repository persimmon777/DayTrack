import DayTrackCore
import Foundation
import SwiftData
import UserNotifications

/// Таймер отдыха: состояние хранится в UserDefaults, чтобы пережить закрытие приложения.
enum RestTimerKeys {
    static let startedAt = "rest.startedAt"
    static let endsAt = "rest.endsAt"
    static let returnTo = "rest.returnTo"
}

@MainActor
enum RestTimer {
    private static let defaults = UserDefaults.standard
    private static let notificationIDs = ["rest-end", "rest-late"]

    static var isRunning: Bool { defaults.double(forKey: RestTimerKeys.endsAt) > 0 }

    static func start(minutes: Int, returnTo: String) async {
        let now = Date.now
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        defaults.set(now.timeIntervalSince1970, forKey: RestTimerKeys.startedAt)
        defaults.set(end.timeIntervalSince1970, forKey: RestTimerKeys.endsAt)
        defaults.set(returnTo, forKey: RestTimerKeys.returnTo)

        let title = returnTo.isEmpty ? "Отдых" : "Отдых · потом: \(returnTo)"
        try? await RestTimerController.start(title: title, duration: TimeInterval(minutes * 60))

        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        center.removePendingNotificationRequests(withIdentifiers: notificationIDs)
        func schedule(_ id: String, after seconds: TimeInterval, title: String, body: String) async {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
        let next = returnTo.isEmpty ? "к делам" : "к «\(returnTo)»"
        await schedule("rest-end", after: end.timeIntervalSince(now), title: "Отдых закончился",
                       body: "Возвращайся \(next). Начни с самого маленького шага.")
        await schedule("rest-late", after: end.timeIntervalSince(now) + 10 * 60, title: "Отдых затянулся на 10 минут",
                       body: "Ничего страшного. Нажми «Я вернулся», когда приступишь \(next).")
    }

    /// Завершает отдых и записывает его в факт с реальной длительностью.
    /// Возвращает запланированные и фактические минуты.
    @discardableResult
    static func finish(context: ModelContext) async -> (planned: Int, actual: Int)? {
        guard isRunning else { return nil }
        let start = Date(timeIntervalSince1970: defaults.double(forKey: RestTimerKeys.startedAt))
        let plannedEnd = Date(timeIntervalSince1970: defaults.double(forKey: RestTimerKeys.endsAt))
        let end = Date.now
        clear()
        await RestTimerController.stopAll()

        let planned = PlanComparison.minutes(from: start, to: plannedEnd)
        let actual = PlanComparison.minutes(from: start, to: end)
        guard actual >= 1 else { return (planned, actual) }

        let clock = DayClock.app
        let dayKey = clock.key(for: start)
        let store = DayStore(context: context)
        let categories = (try? context.fetch(FetchDescriptor<ActivityCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let rest = categories.first { $0.kind == .rest && !$0.isArchived }

        // Если отдых был в плане, запись привязывается к этому блоку.
        let block = store.day(forKey: dayKey)?.activeBlocks
            .filter { $0.category?.kind == .rest }
            .max { overlap($0, start, end) < overlap($1, start, end) }
            .flatMap { overlap($0, start, end) > 0 ? $0 : nil }

        store.addFact(
            dayKey: dayKey, block: block, title: block?.title ?? "Отдых", category: block?.category ?? rest,
            start: start, end: end, reason: block == nil ? .other : nil, note: ""
        )
        return (planned, actual)
    }

    static func cancel() async {
        clear()
        await RestTimerController.stopAll()
    }

    private static func clear() {
        defaults.removeObject(forKey: RestTimerKeys.startedAt)
        defaults.set(0.0, forKey: RestTimerKeys.endsAt)
        defaults.removeObject(forKey: RestTimerKeys.returnTo)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIDs)
    }

    private static func overlap(_ block: PlannedBlock, _ start: Date, _ end: Date) -> TimeInterval {
        min(end, block.end).timeIntervalSince(max(start, block.start))
    }
}
