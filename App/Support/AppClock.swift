import DayTrackCore
import Foundation

extension DayClock {
    /// Часы приложения: день начинается в 04:00 по времени телефона.
    static var app: DayClock { DayClock(calendar: .current, startHour: 4) }
}

/// Запись дат и времени по-русски, независимо от языка телефона.
enum Format {
    static let locale = Locale(identifier: "ru_RU")

    private static func formatter(_ template: String, fixed: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        if fixed {
            formatter.dateFormat = template
        } else {
            formatter.setLocalizedDateFormatFromTemplate(template)
        }
        return formatter
    }

    private static let timeFormatter = formatter("HH:mm", fixed: true)
    private static let dayFormatter = formatter("EEE d MMMM")
    private static let dayWithYearFormatter = formatter("d MMMM yyyy")

    /// «09:30»
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// «09:30–11:00»
    static func timeRange(_ start: Date, _ end: Date) -> String {
        "\(time(start))–\(time(end))"
    }

    /// «вт, 10 ноября»
    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// «10 ноября 2026 г.»
    static func dayWithYear(_ date: Date) -> String {
        dayWithYearFormatter.string(from: date)
    }
}
