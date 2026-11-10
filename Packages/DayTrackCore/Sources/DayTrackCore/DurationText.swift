import Foundation

/// Запись длительности словами: «45 мин», «2 ч», «1 ч 30 мин».
public enum DurationText {
    public static func short(minutes: Int) -> String {
        let total = max(0, minutes)
        let hours = total / 60
        let rest = total % 60
        if hours == 0 { return "\(rest) мин" }
        if rest == 0 { return "\(hours) ч" }
        return "\(hours) ч \(rest) мин"
    }

    /// Доля в процентах без дробной части: 0.584 → «58%».
    public static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}
