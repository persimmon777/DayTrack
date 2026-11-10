import Foundation

/// Число, которое приложение передаёт тестовому виджету.
struct InstallCheckSnapshot: Codable, Equatable {
    var number: Int
    var writtenAt: Date
}

/// Отметка виджета о том, что он прочитал число. По ней приложение видит,
/// что данные дошли, без сравнения на глаз.
struct InstallCheckAck: Codable, Equatable {
    var number: Int
    var readAt: Date
}

/// Обмен данными между приложением и тестовым виджетом через общую папку.
enum InstallCheckStore {
    enum ReadError: Error, Equatable {
        case noContainer
        case noData
        case unreadable
    }

    static let widgetKind = "DayTrackInstallCheckWidget"

    private static let snapshotFile = "install-check-snapshot.json"
    private static let ackFile = "install-check-ack.json"

    private static func fileURL(_ name: String) -> URL? {
        SharedContainer.url?.appendingPathComponent(name)
    }

    private static func read<T: Decodable>(_ type: T.Type, from name: String) -> Result<T, ReadError> {
        guard let url = fileURL(name) else { return .failure(.noContainer) }
        guard let data = try? Data(contentsOf: url) else { return .failure(.noData) }
        guard let value = try? JSONDecoder().decode(type, from: data) else {
            return .failure(.unreadable)
        }
        return .success(value)
    }

    private static func write<T: Encodable>(_ value: T, to name: String) throws {
        guard let url = fileURL(name) else { throw ReadError.noContainer }
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }

    static func writeSnapshot(_ snapshot: InstallCheckSnapshot) throws {
        try write(snapshot, to: snapshotFile)
    }

    static func readSnapshot() -> Result<InstallCheckSnapshot, ReadError> {
        read(InstallCheckSnapshot.self, from: snapshotFile)
    }

    static func writeAck(_ ack: InstallCheckAck) {
        try? write(ack, to: ackFile)
    }

    static func readAck() -> InstallCheckAck? {
        try? read(InstallCheckAck.self, from: ackFile).get()
    }
}
