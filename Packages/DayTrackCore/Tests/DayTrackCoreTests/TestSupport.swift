import Foundation

enum TestTime {
    static func calendar(timeZone: String = "Europe/Moscow") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    /// Дата по московскому времени (или в указанном поясе).
    static func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0,
        timeZone: String = "Europe/Moscow"
    ) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return calendar(timeZone: timeZone).date(from: parts)!
    }
}
