import Foundation

/// Период аналитики.
public enum PeriodKind: String, CaseIterable, Codable, Sendable {
    case day
    case week
    case month

    public var title: String {
        switch self {
        case .day: return "День"
        case .week: return "Неделя"
        case .month: return "Месяц"
        }
    }
}

/// Границы периодов по ключам дней. Неделя начинается с понедельника.
public enum Periods {
    /// Первый и последний день периода, в который входит `key`.
    public static func range(_ kind: PeriodKind, containing key: Int, calendar: Calendar) -> ClosedRange<Int> {
        switch kind {
        case .day:
            return key...key
        case .week:
            let start = weekStart(key, calendar: calendar)
            return start...Recurrence.key(start, addingDays: 6, calendar: calendar)
        case .month:
            let date = DayDate(key: key)
            let days = Recurrence.daysInMonth(year: date.year, month: date.month, calendar: calendar)
            let first = date.year * 10_000 + date.month * 100 + 1
            return first...(first + days - 1)
        }
    }

    /// Понедельник недели дня.
    public static func weekStart(_ key: Int, calendar: Calendar) -> Int {
        guard let date = Recurrence.date(forKey: key, calendar: calendar) else { return key }
        let weekday = calendar.component(.weekday, from: date)
        let shift = (weekday + 5) % 7
        return Recurrence.key(key, addingDays: -shift, calendar: calendar)
    }

    /// День того же периода, сдвинутого на `steps` периодов вперёд или назад.
    public static func shift(_ key: Int, kind: PeriodKind, by steps: Int, calendar: Calendar) -> Int {
        switch kind {
        case .day:
            return Recurrence.key(key, addingDays: steps, calendar: calendar)
        case .week:
            return Recurrence.key(key, addingDays: 7 * steps, calendar: calendar)
        case .month:
            let date = DayDate(key: key)
            var month = date.month - 1 + steps
            var year = date.year
            year += Int((Double(month) / 12).rounded(.down))
            month = ((month % 12) + 12) % 12 + 1
            let day = min(date.day, Recurrence.daysInMonth(year: year, month: month, calendar: calendar))
            return year * 10_000 + month * 100 + day
        }
    }

    /// Все дни промежутка по порядку.
    public static func days(in range: ClosedRange<Int>, calendar: Calendar) -> [Int] {
        var result: [Int] = []
        var key = range.lowerBound
        while key <= range.upperBound, result.count < 400 {
            result.append(key)
            key = Recurrence.key(key, addingDays: 1, calendar: calendar)
        }
        return result
    }
}
