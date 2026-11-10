import SwiftUI

/// Четыре вкладки приложения. «Фокусы» и «Аналитика» появятся на этапе 2.
struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
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

            SettingsView()
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
