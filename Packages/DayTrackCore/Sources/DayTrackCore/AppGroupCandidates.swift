import Foundation

/// Порядок, в котором приложение и виджет пробуют идентификаторы общей группы.
///
/// Обе стороны должны прийти к одному и тому же идентификатору, поэтому порядок
/// не зависит от того, в каком порядке группы перечислены в профиле.
public enum AppGroupCandidates {
    public static func ordered(
        profileGroups: [String],
        declaredGroup: String,
        mainAppBundleID: String?
    ) -> [String] {
        var result: [String] = []
        func add(_ id: String) {
            guard !id.isEmpty, !result.contains(id) else { return }
            result.append(id)
        }

        // Сначала то, что реально разрешено профилем подписи.
        profileGroups.sorted().forEach(add)
        // Затем группа, объявленная в проекте.
        add(declaredGroup)
        // Затем группа, которую установщики обычно создают по идентификатору приложения.
        if let mainAppBundleID { add("group.\(mainAppBundleID)") }
        return result
    }
}
