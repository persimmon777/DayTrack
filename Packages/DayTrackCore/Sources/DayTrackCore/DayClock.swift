import Foundation

/// Границы «логического» дня.
///
/// День начинается не в полночь, а в `startHour` (по умолчанию 04:00), поэтому
/// сделанное в два часа ночи относится к предыдущему дню. День обозначается
/// ключом вида 20261110.
public struct DayClock: Sendable {
    public var calendar: Calendar
    public var startHour: Int

    public init(calendar: Calendar = .current, startHour: Int = 4) {
        self.calendar = calendar
        self.startHour = min(max(startHour, 0), 12)
    }

    /// Ключ дня, к которому относится момент времени.
    public func key(for date: Date) -> Int {
        let shifted = calendar.date(byAdding: .hour, value: -startHour, to: date) ?? date
        let parts = calendar.dateComponents([.year, .month, .day], from: shifted)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    /// Полночь календарной даты, которой соответствует ключ.
    public func calendarDate(forKey key: Int) -> Date? {
        var parts = DateComponents()
        parts.year = key / 10_000
        parts.month = (key / 100) % 100
        parts.day = key % 100
        guard let date = calendar.date(from: parts) else { return nil }
        // Отсекаем несуществующие даты вроде 31 февраля.
        return self.key(for: dayStart(onCalendarDay: date)) == key ? date : nil
    }

    /// Интервал дня: от его начала до начала следующего.
    public func window(forKey key: Int) -> DateInterval? {
        guard
            let date = calendarDate(forKey: key),
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)
        else { return nil }
        let start = dayStart(onCalendarDay: date)
        let end = dayStart(onCalendarDay: nextDate)
        guard end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Ключ дня, отстоящего на `days` суток.
    public func key(byAdding days: Int, to key: Int) -> Int {
        guard
            let date = calendarDate(forKey: key),
            let moved = calendar.date(byAdding: .day, value: days, to: date)
        else { return key }
        return self.key(for: dayStart(onCalendarDay: moved))
    }

    /// Момент внутри дня с данным временем на часах. Время раньше начала дня
    /// (например, 01:30) приходится на следующую календарную дату.
    public func resolve(hour: Int, minute: Int, inDay key: Int) -> Date? {
        guard let date = calendarDate(forKey: key) else { return nil }
        let isBeforeDayStart = hour < startHour
        let base = isBeforeDayStart
            ? calendar.date(byAdding: .day, value: 1, to: date) ?? date
            : date
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)
    }

    /// То же для времени, взятого из произвольной даты (например, из выбора времени в форме).
    public func resolve(timeOf date: Date, inDay key: Int) -> Date? {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return resolve(hour: parts.hour ?? 0, minute: parts.minute ?? 0, inDay: key)
    }

    /// Ближайший момент строго после `start` с данным временем на часах.
    /// Так конец блока «23:30–07:30» попадает на следующее утро.
    public func end(after start: Date, hour: Int, minute: Int) -> Date {
        var parts = DateComponents()
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        return calendar.nextDate(after: start, matching: parts, matchingPolicy: .nextTime)
            ?? start.addingTimeInterval(3600)
    }

    public func end(after start: Date, timeOf date: Date) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return end(after: start, hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    private func dayStart(onCalendarDay date: Date) -> Date {
        calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: date) ?? date
    }
}
