import DayTrackCore
import SwiftUI

/// Вкладки приложения. Выбранный день общий для «Плана», «Факта» и «Аналитики».
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var dayKey = DayClock.app.key(for: .now)
    /// Какой день был «сегодня», когда приложение было открыто в прошлый раз.
    @State private var lastTodayKey = DayClock.app.key(for: .now)

    var body: some View {
        TabView {
            DayPager(dayKey: $dayKey) { PlanView(dayKey: $0) }
                .tabItem { Label("План", systemImage: "list.bullet.clipboard") }

            DayPager(dayKey: $dayKey) { FactView(dayKey: $0) }
                .tabItem { Label("Факт", systemImage: "checkmark.circle") }

            PlaceholderTab(
                title: "Фокусы",
                systemImage: "scope",
                note: "Фокусы недели и месяца появятся на этапе 2."
            )
            .tabItem { Label("Фокусы", systemImage: "scope") }

            DayPager(dayKey: $dayKey) { AnalyticsDayView(dayKey: $0) }
                .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Если приложение открыли на следующий день, а был выбран «сегодня»,
            // переходим на новый сегодняшний день.
            let today = DayClock.app.key(for: .now)
            if dayKey == lastTodayKey, today != lastTodayKey {
                dayKey = today
            }
            lastTodayKey = today
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
