import Foundation

/// Как повторяется напоминание.
public enum RepeatRule: String, CaseIterable, Codable, Sendable {
    case none
    case weekly
    case monthly
    case yearly

    public var title: String {
        switch self {
        case .none: return "Не повторять"
        case .weekly: return "Каждую неделю"
        case .monthly: return "Каждый месяц"
        case .yearly: return "Каждый год"
        }
    }
}

/// Дата без времени, записанная ключом дня вида 20261110.
public struct DayDate: Equatable, Comparable, Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(key: Int) {
        self.init(year: key / 10_000, month: (key / 100) % 100, day: key % 100)
    }

    public var key: Int { year * 10_000 + month * 100 + day }

    public static func < (lhs: DayDate, rhs: DayDate) -> Bool { lhs.key < rhs.key }
}

public enum Recurrence {
    /// Число дней в месяце.
    public static func daysInMonth(year: Int, month: Int, calendar: Calendar) -> Int {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = 1
        guard let date = calendar.date(from: parts),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 31 }
        return range.count
    }

    /// День месяца, в который приходится повтор: 31-е в коротком месяце
    /// переносится на последний день, 29 февраля — на 28-е в невисокосный год.
    private static func clampedDay(_ day: Int, year: Int, month: Int, calendar: Calendar) -> Int {
        min(day, daysInMonth(year: year, month: month, calendar: calendar))
    }

    private static func weekday(_ date: DayDate, calendar: Calendar) -> Int? {
        var parts = DateComponents()
        parts.year = date.year
        parts.month = date.month
        parts.day = date.day
        return calendar.date(from: parts).map { calendar.component(.weekday, from: $0) }
    }

    /// Приходится ли напоминание с первой датой `first` на день `key`.
    public static func occurs(on key: Int, first: Int, rule: RepeatRule, calendar: Calendar) -> Bool {
        let target = DayDate(key: key)
        let start = DayDate(key: first)
        guard target >= start else { return false }

        switch rule {
        case .none:
            return target == start
        case .weekly:
            guard let a = weekday(target, calendar: calendar), let b = weekday(start, calendar: calendar) else {
                return false
            }
            return a == b
        case .monthly:
            return target.day == clampedDay(start.day, year: target.year, month: target.month, calendar: calendar)
        case .yearly:
            guard target.month == start.month else { return false }
            return target.day == clampedDay(start.day, year: target.year, month: target.month, calendar: calendar)
        }
    }

    /// Все дни из промежутка `[from, through]`, на которые приходится напоминание.
    /// Промежуток не длиннее двух лет.
    public static func occurrences(
        first: Int, rule: RepeatRule, from: Int, through: Int, calendar: Calendar
    ) -> [Int] {
        guard let startDate = date(forKey: from, calendar: calendar) else { return [] }
        var result: [Int] = []
        for offset in 0..<731 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { break }
            let key = keyOf(date, calendar: calendar)
            if key > through { break }
            if occurs(on: key, first: first, rule: rule, calendar: calendar) { result.append(key) }
        }
        return result
    }

    /// Полдень календарной даты ключа (полдень не страдает от перевода часов).
    public static func date(forKey key: Int, calendar: Calendar) -> Date? {
        let day = DayDate(key: key)
        var parts = DateComponents()
        parts.year = day.year
        parts.month = day.month
        parts.day = day.day
        parts.hour = 12
        return calendar.date(from: parts)
    }

    public static func keyOf(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    /// Ключ дня, сдвинутого на `days` суток.
    public static func key(_ key: Int, addingDays days: Int, calendar: Calendar) -> Int {
        guard let date = date(forKey: key, calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: days, to: date) else { return key }
        return keyOf(moved, calendar: calendar)
    }
}
