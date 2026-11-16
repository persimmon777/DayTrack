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
                    NavigationLink {
                        ScheduleView()
                    } label: {
                        Label("Расписание", systemImage: "calendar.badge.clock")
                    }
                    NavigationLink {
                        TemplatesView()
                    } label: {
                        Label("Шаблоны дня", systemImage: "square.on.square")
                    }
                    NavigationLink {
                        RemindersListView()
                    } label: {
                        Label("Напоминания", systemImage: "bell.badge")
                    }
                }

                Section("Подсказки и вид") {
                    NavigationLink {
                        AdvisorSettingsView()
                    } label: {
                        Label("Советчик", systemImage: "lightbulb")
                    }
                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        Label("Оформление", systemImage: "paintpalette")
                    }
                }

                Section("Напоминания и виджет") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Уведомления", systemImage: "bell")
                    }
                    NavigationLink {
                        BalanceTargetView()
                    } label: {
                        Label("Цель баланса", systemImage: "chart.pie")
                    }
                }

                Section("Аналитика") {
                    NavigationLink {
                        ReportPromptView()
                    } label: {
                        Label("Запрос для нейросети", systemImage: "text.bubble")
                    }
                }

                Section("Данные") {
                    NavigationLink {
                        BackupView()
                    } label: {
                        Label("Резервные копии", systemImage: "externaldrive.badge.timemachine")
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
