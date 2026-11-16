import Foundation

/// Мягкие серии: день засчитывается, если в нём есть план и вечерний разбор.
/// Один пропуск в неделю (с понедельника по воскресенье) серию не рвёт.
public enum Streaks {
    /// Длина серии на сегодня. Сегодняшний день, пока не закрыт, серию не рвёт.
    public static func softStreak(doneKeys: Set<Int>, today: Int, calendar: Calendar) -> Int {
        var streak = 0
        var missesByWeek: [Int: Int] = [:]
        var key = doneKeys.contains(today) ? today : Recurrence.key(today, addingDays: -1, calendar: calendar)
        var pendingMisses = 0
        for _ in 0..<800 {
            if doneKeys.contains(key) {
                streak += 1 + pendingMisses
                pendingMisses = 0
            } else {
                let week = Periods.weekStart(key, calendar: calendar)
                let misses = (missesByWeek[week] ?? 0) + 1
                missesByWeek[week] = misses
                if misses > 1 { break }
                // Прощённый пропуск входит в серию, только если перед ним есть засчитанные дни.
                pendingMisses += 1
            }
            key = Recurrence.key(key, addingDays: -1, calendar: calendar)
        }
        return streak
    }

    /// Сколько дней из последних `days` (включая сегодня) засчитано.
    public static func count(doneKeys: Set<Int>, lastDays days: Int, today: Int, calendar: Calendar) -> Int {
        (0..<days).filter { doneKeys.contains(Recurrence.key(today, addingDays: -$0, calendar: calendar)) }.count
    }
}
