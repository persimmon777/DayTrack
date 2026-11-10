import Foundation
import DayTrackCore

/// Общая папка приложения и виджета.
///
/// Идентификатор группы не зашит в код намертво: установщик может его заменить,
/// поэтому он определяется при запуске по профилю подписи.
enum SharedContainer {
    /// Группа, объявленная в проекте (`Config/*.entitlements`).
    static let declaredGroupID = "group.app.daytrack.DayTrack"

    struct Resolution {
        /// Идентификатор текущего процесса (приложения или виджета).
        let bundleID: String
        /// Идентификатор основного приложения.
        let mainAppBundleID: String?
        let profileFound: Bool
        let profileGroups: [String]
        let candidates: [String]
        let groupID: String?
        let containerURL: URL?

        var isAvailable: Bool { containerURL != nil }
    }

    /// Результат поиска. Считается один раз за запуск процесса.
    static let resolution: Resolution = resolve()

    static var url: URL? { resolution.containerURL }

    private static func resolve() -> Resolution {
        let bundle = Bundle.main
        let profileData = bundle
            .url(forResource: "embedded", withExtension: "mobileprovision")
            .flatMap { try? Data(contentsOf: $0) }
        let profileGroups = profileData.map(ProvisioningProfile.appGroups(fromProfileData:)) ?? []
        let mainAppBundleID = mainAppBundle(for: bundle)?.bundleIdentifier

        let candidates = AppGroupCandidates.ordered(
            profileGroups: profileGroups,
            declaredGroup: declaredGroupID,
            mainAppBundleID: mainAppBundleID
        )

        var groupID: String?
        var containerURL: URL?
        for candidate in candidates {
            guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: candidate),
                isWritable(url)
            else { continue }
            groupID = candidate
            containerURL = url
            break
        }

        return Resolution(
            bundleID: bundle.bundleIdentifier ?? "неизвестно",
            mainAppBundleID: mainAppBundleID,
            profileFound: profileData != nil,
            profileGroups: profileGroups,
            candidates: candidates,
            groupID: groupID,
            containerURL: containerURL
        )
    }

    /// Виджет лежит внутри приложения: `DayTrack.app/PlugIns/Widgets.appex`.
    private static func mainAppBundle(for bundle: Bundle) -> Bundle? {
        guard bundle.bundleURL.pathExtension == "appex" else { return bundle }
        let appURL = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        return Bundle(url: appURL)
    }

    /// Система может вернуть путь даже к группе, на которую нет прав,
    /// поэтому доступ проверяется настоящей записью.
    private static func isWritable(_ url: URL) -> Bool {
        let probe = url.appendingPathComponent(".daytrack-probe-\(UUID().uuidString)")
        do {
            try Data("ok".utf8).write(to: probe, options: .atomic)
            try? FileManager.default.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }
}
