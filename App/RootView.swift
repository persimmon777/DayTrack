import SwiftUI

/// Четыре вкладки приложения. На этапе 0 вкладка «Сегодня» занята проверкой
/// установки, остальные пока пустые.
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                InstallCheckView()
            }
            .tabItem { Label("Сегодня", systemImage: "calendar.day.timeline.left") }

            PlaceholderTab(
                title: "Фокусы",
                systemImage: "scope",
                note: "Фокусы недели и месяца появятся на этапе 2."
            )
            .tabItem { Label("Фокусы", systemImage: "scope") }

            PlaceholderTab(
                title: "Аналитика",
                systemImage: "chart.bar.xaxis",
                note: "Графики, календарь и отчёт появятся на этапе 2."
            )
            .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }

            PlaceholderTab(
                title: "Настройки",
                systemImage: "gearshape",
                note: "Категории, расписание и резервные копии появятся на этапе 1."
            )
            .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
    }
}

private struct PlaceholderTab: View {
    let title: String
    let systemImage: String
    let note: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text(note))
                .navigationTitle(title)
        }
    }
}
