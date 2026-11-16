import Foundation

/// Минуты по группам баланса.
struct BalanceMinutes: Codable, Equatable {
    var study = 0
    var rest = 0
    var sleep = 0
    var other = 0
}

/// Данные, которые приложение передаёт виджету баланса.
struct WidgetSnapshot: Codable, Equatable {
    var writtenAt: Date
    /// День, к которому относится `today` (ключ вида 20261116).
    var dayKey: Int
    var today: BalanceMinutes
    var week: BalanceMinutes
    /// Сколько дней недели уже прошло, включая сегодняшний (для цели на неделю).
    var weekDaysElapsed: Int
    /// Цель на один день.
    var target: BalanceMinutes
}

enum WidgetSnapshotStore {
    static let widgetKind = "DayTrackBalanceWidget"
    private static let fileName = "widget-snapshot.json"

    private static var url: URL? {
        SharedContainer.url?.appendingPathComponent(fileName)
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func read() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
