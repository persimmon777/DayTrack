import Foundation

/// По каким неделям действует правило расписания.
public enum WeekParity: String, CaseIterable, Codable, Sendable {
    case every
    case odd
    case even

    public var title: String {
        switch self {
        case .every: return "Каждую неделю"
        case .odd: return "По нечётным"
        case .even: return "По чётным"
        }
    }
}

/// Правило расписания в виде, нужном для проверки.
public struct ScheduleRuleData: Equatable, Sendable {
    /// День недели по `Calendar`: 1 — воскресенье, 2 — понедельник, … 7 — суббота.
    public var weekday: Int
    public var parity: WeekParity
    public var validFromKey: Int?
    public var validUntilKey: Int?
    public var isEnabled: Bool

    public init(weekday: Int, parity: WeekParity, validFromKey: Int? = nil, validUntilKey: Int? = nil, isEnabled: Bool = true) {
        self.weekday = weekday
        self.parity = parity
        self.validFromKey = validFromKey
        self.validUntilKey = validUntilKey
        self.isEnabled = isEnabled
    }
}

public enum WeeklySchedule {
    /// Номер учебной недели дня: неделя, в которую входит `firstWeekKey`, — первая.
    /// Недели начинаются с понедельника. Дни до первой недели получают номер 0 и меньше.
    public static func weekNumber(of key: Int, firstWeekKey: Int, calendar: Calendar) -> Int? {
        guard
            let day = Recurrence.date(forKey: key, calendar: calendar),
            let first = Recurrence.date(forKey: firstWeekKey, calendar: calendar)
        else { return nil }
        let dayMonday = monday(of: day, calendar: calendar)
        let firstMonday = monday(of: first, calendar: calendar)
        let days = calendar.dateComponents([.day], from: firstMonday, to: dayMonday).day ?? 0
        // Деление с округлением вниз, чтобы недели до начала тоже считались верно.
        let weeks = Int((Double(days) / 7).rounded(.down))
        return weeks + 1
    }

    private static func monday(of date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let shift = (weekday + 5) % 7 // понедельник → 0, воскресенье → 6
        let start = calendar.startOfDay(for: date)
        let monday = calendar.date(byAdding: .day, value: -shift, to: start) ?? start
        return calendar.date(byAdding: .hour, value: 12, to: monday) ?? monday
    }

    /// Действует ли правило в этот день.
    public static func applies(_ rule: ScheduleRuleData, on key: Int, firstWeekKey: Int, calendar: Calendar) -> Bool {
        guard rule.isEnabled else { return false }
        if let from = rule.validFromKey, key < from { return false }
        if let until = rule.validUntilKey, key > until { return false }
        guard let date = Recurrence.date(forKey: key, calendar: calendar),
              calendar.component(.weekday, from: date) == rule.weekday else { return false }

        switch rule.parity {
        case .every:
            return true
        case .odd, .even:
            guard let week = weekNumber(of: key, firstWeekKey: firstWeekKey, calendar: calendar) else { return false }
            let isOdd = abs(week) % 2 == 1
            return rule.parity == .odd ? isOdd : !isOdd
        }
    }

    /// Начало учебного года по умолчанию: 1 сентября текущего учебного года.
    public static func defaultFirstWeekKey(today: Int) -> Int {
        let date = DayDate(key: today)
        let year = date.month >= 9 ? date.year : date.year - 1
        return year * 10_000 + 901
    }
}
