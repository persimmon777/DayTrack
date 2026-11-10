import ActivityKit
import Foundation

/// Данные таймера отдыха на экране блокировки.
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Момент, когда отдых заканчивается.
        var endDate: Date
    }

    /// Подпись таймера.
    var title: String
}

extension RestTimerAttributes.ContentState {
    /// Интервал для обратного отсчёта. Начало не может быть позже конца,
    /// иначе создание интервала аварийно завершит процесс.
    func countdownRange(now: Date = .now) -> ClosedRange<Date> {
        min(now, endDate)...endDate
    }
}
