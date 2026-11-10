import Foundation

/// Чтение профиля подписи (`embedded.mobileprovision`), который кладёт в приложение
/// программа установки.
///
/// При установке через сторонний установщик идентификатор общей группы приложений
/// может быть заменён на другой. Настоящий идентификатор записан в профиле,
/// поэтому приложение и виджет узнают его отсюда, а не из кода.
public enum ProvisioningProfile {
    static let appGroupsKey = "com.apple.security.application-groups"

    /// Права из профиля. Профиль представляет собой подписанный контейнер,
    /// внутри которого лежит обычный XML-список свойств.
    public static func entitlements(fromProfileData data: Data) -> [String: Any]? {
        guard
            let start = data.range(of: Data("<?xml".utf8)),
            let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }

        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard
            let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil),
            let root = plist as? [String: Any]
        else { return nil }

        return root["Entitlements"] as? [String: Any]
    }

    /// Группы приложений, разрешённые профилем. Пустой список, если профиля нет,
    /// он не читается или групп в нём нет.
    public static func appGroups(fromProfileData data: Data) -> [String] {
        guard let entitlements = entitlements(fromProfileData: data) else { return [] }
        if let groups = entitlements[appGroupsKey] as? [String] { return groups }
        if let group = entitlements[appGroupsKey] as? String { return [group] }
        return []
    }
}
