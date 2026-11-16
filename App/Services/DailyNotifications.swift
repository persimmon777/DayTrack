import DayTrackCore
import Foundation
import SwiftData
import UserNotifications

/// Настройки ежедневных уведомлений.
enum NotificationSettings {
    private static let defaults = UserDefaults.standard

    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }

    private static func minute(_ key: String, _ fallback: Int) -> Int {
        defaults.object(forKey: key) as? Int ?? fallback
    }

    static var morningOn: Bool {
        get { bool("notify.morning", true) }
        set { defaults.set(newValue, forKey: "notify.morning") }
    }
    static var morningMinute: Int {
        get { minute("notify.morningMinute", 8 * 60) }
        set { defaults.set(newValue, forKey: "notify.morningMinute") }
    }
    static var eveningOn: Bool {
        get { bool("notify.evening", true) }
        set { defaults.set(newValue, forKey: "notify.evening") }
    }
    static var eveningMinute: Int {
        get { minute("notify.eveningMinute", 21 * 60 + 30) }
        set { defaults.set(newValue, forKey: "notify.eveningMinute") }
    }
    static var factOn: Bool {
        get { bool("notify.fact", true) }
        set { defaults.set(newValue, forKey: "notify.fact") }
    }
    static var factMinutes: [Int] {
        get { (defaults.array(forKey: "notify.factMinutes") as? [Int]) ?? [13 * 60, 18 * 60] }
        set { defaults.set(newValue, forKey: "notify.factMinutes") }
    }
    static var breakOn: Bool {
        get { bool("notify.break", true) }
        set { defaults.set(newValue, forKey: "notify.break") }
    }
    /// Через сколько минут учёбы без паузы напомнить о перерыве.
    static var breakInterval: Int {
        get { minute("notify.breakInterval", 90) }
        set { defaults.set(newValue, forKey: "notify.breakInterval") }
    }
}

/// Утренние и вечерние уведомления, напоминания внести факт и сделать перерыв.
/// Ставятся на ближайшие дни и пересобираются при каждом открытии и сворачивании приложения.
@MainActor
enum DailyNotifications {
    private static let prefixes = ["daily-", "fact-", "break-"]

    static func reschedule(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { id in prefixes.contains { id.hasPrefix($0) } }
        )
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let clock = DayClock.app
        let now = Date.now
        let todayKey = clock.key(for: now)
        var requests: [UNNotificationRequest] = []

        func add(_ id: String, at date: Date, title: String, body: String) {
            guard date > now else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            requests.append(UNNotificationRequest(
                identifier: id, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            ))
        }

        for offset in 0..<5 {
            let key = clock.key(byAdding: offset, to: todayKey)
            if NotificationSettings.morningOn,
               let date = clock.resolve(hour: NotificationSettings.morningMinute / 60, minute: NotificationSettings.morningMinute % 60, inDay: key) {
                add("daily-morning-\(key)", at: date, title: "Доброе утро",
                    body: "Загляни в план на сегодня: что главное и где отдых?")
            }
            if NotificationSettings.eveningOn,
               let date = clock.resolve(hour: NotificationSettings.eveningMinute / 60, minute: NotificationSettings.eveningMinute % 60, inDay: key) {
                add("daily-evening-\(key)", at: date, title: "Время подвести итоги",
                    body: "Внеси факт за день и ответь на три вопроса разбора. Это пара минут.")
            }
        }

        if NotificationSettings.factOn {
            let store = DayStore(context: context)
            let lastFactEnd = store.day(forKey: todayKey)?.facts.map(\.end).max()
            for offset in 0..<3 {
                let key = clock.key(byAdding: offset, to: todayKey)
                for (index, minute) in NotificationSettings.factMinutes.enumerated() {
                    guard let date = clock.resolve(hour: minute / 60, minute: minute % 60, inDay: key) else { continue }
                    // Если факт уже внесён почти до этого времени, напоминать незачем.
                    if offset == 0, let lastFactEnd, date.timeIntervalSince(lastFactEnd) < 2 * 3600 { continue }
                    add("fact-\(key)-\(index)", at: date, title: "Что было за последние часы?",
                        body: "Отметь факт, пока помнишь: это быстрее, чем вспоминать вечером.")
                }
            }
        }

        if NotificationSettings.breakOn {
            requests += breakRequests(context: context, todayKey: todayKey, now: now).prefix(8)
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    /// Напоминания о перерыве посреди длинной учёбы по плану.
    private static func breakRequests(context: ModelContext, todayKey: Int, now: Date) -> [UNNotificationRequest] {
        let clock = DayClock.app
        let store = DayStore(context: context)
        let interval = TimeInterval(NotificationSettings.breakInterval * 60)
        var result: [UNNotificationRequest] = []

        for key in [todayKey, clock.key(byAdding: 1, to: todayKey)] {
            let blocks = (store.day(forKey: key)?.activeBlocks ?? [])
                .filter { $0.category?.kind == .study }
                .sorted { $0.start < $1.start }
            // Блоки учёбы с паузой меньше 10 минут считаются одним отрезком.
            var runs: [(start: Date, end: Date)] = []
            for block in blocks {
                if let last = runs.last, block.start.timeIntervalSince(last.end) < 10 * 60 {
                    runs[runs.count - 1].end = max(last.end, block.end)
                } else {
                    runs.append((block.start, block.end))
                }
            }
            for run in runs {
                var fire = run.start.addingTimeInterval(interval)
                while fire < run.end.addingTimeInterval(-10 * 60) {
                    if fire > now {
                        let content = UNMutableNotificationContent()
                        content.title = "Пора сделать перерыв"
                        content.body = "По плану ты учишься уже \(DurationText.short(minutes: Int(fire.timeIntervalSince(run.start) / 60))). Встань, пройдись или разомнись 10–15 минут, лучше без телефона: короткие перерывы снижают усталость."
                        content.sound = .default
                        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                        result.append(UNNotificationRequest(
                            identifier: "break-\(Int(fire.timeIntervalSince1970))",
                            content: content,
                            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                        ))
                    }
                    fire = fire.addingTimeInterval(interval)
                }
            }
        }
        return result
    }
}
