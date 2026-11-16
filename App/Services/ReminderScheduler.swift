import DayTrackCore
import Foundation
import SwiftData
import UserNotifications

/// Уведомления о напоминаниях. iOS хранит не больше 64 запланированных
/// уведомлений, поэтому ставятся только ближайшие, а список пересобирается
/// при каждом открытии приложения и после каждой правки.
@MainActor
enum ReminderScheduler {
    private static let prefix = "reminder-"
    private static let horizonDays = 60
    private static let maxScheduled = 30
    /// Время уведомления для напоминаний на весь день.
    private static let allDayMinute = 9 * 60

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func reschedule(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        )

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let calendar = Calendar.current
        let now = Date.now
        let todayKey = Recurrence.keyOf(now, calendar: calendar)
        let reminders = ((try? context.fetch(FetchDescriptor<Reminder>())) ?? []).filter(\.notify)

        var requests: [(date: Date, request: UNNotificationRequest)] = []
        for reminder in reminders {
            // Предупреждение заранее может прийти на дни раньше события.
            let fromKey = todayKey
            let throughKey = Recurrence.key(todayKey, addingDays: horizonDays + reminder.leadDays, calendar: calendar)
            let days = Recurrence.occurrences(
                first: reminder.firstDayKey, rule: reminder.repeatRule,
                from: fromKey, through: throughKey, calendar: calendar
            )
            for dayKey in days {
                let notifyDayKey = Recurrence.key(dayKey, addingDays: -reminder.leadDays, calendar: calendar)
                let minute = reminder.leadDays > 0 ? allDayMinute : (reminder.minuteOfDay ?? allDayMinute)
                guard let fireDate = date(dayKey: notifyDayKey, minute: minute, calendar: calendar),
                      fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = reminder.title
                content.body = body(for: reminder, dayKey: dayKey, calendar: calendar)
                content.sound = .default

                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let request = UNNotificationRequest(
                    identifier: "\(prefix)\(reminder.uuid.uuidString)-\(dayKey)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                )
                requests.append((fireDate, request))
            }
        }

        for item in requests.sorted(by: { $0.date < $1.date }).prefix(maxScheduled) {
            try? await center.add(item.request)
        }
    }

    private static func date(dayKey: Int, minute: Int, calendar: Calendar) -> Date? {
        let day = DayDate(key: dayKey)
        var parts = DateComponents()
        parts.year = day.year
        parts.month = day.month
        parts.day = day.day
        parts.hour = minute / 60
        parts.minute = minute % 60
        return calendar.date(from: parts)
    }

    private static func body(for reminder: Reminder, dayKey: Int, calendar: Calendar) -> String {
        let when: String
        switch reminder.leadDays {
        case 0: when = "Сегодня"
        case 1: when = "Завтра"
        default:
            let date = Recurrence.date(forKey: dayKey, calendar: calendar) ?? .now
            when = "Через \(reminder.leadDays) дн., \(Format.day(date))"
        }
        let time = reminder.minuteOfDay == nil ? "" : " в \(reminder.timeText)"
        let note = reminder.note.isEmpty ? "" : "\n\(reminder.note)"
        return "\(when)\(time)\(note)"
    }
}
