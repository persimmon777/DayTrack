import SwiftUI

struct SettingsView: View {
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (сборка \(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("План") {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("Категории", systemImage: "square.grid.2x2")
                    }
                }

                Section("Служебное") {
                    NavigationLink {
                        InstallCheckView()
                    } label: {
                        Label("Проверка установки", systemImage: "checklist")
                    }
                    LabeledContent("Версия", value: appVersion)
                }
            }
            .navigationTitle("Настройки")
        }
    }
}
