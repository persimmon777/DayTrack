import SwiftData
import SwiftUI
import UserNotifications

@main
struct DayTrackApp: App {
    private let database = AppDatabase.openContainer()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        if case .success(let container) = database {
            AppDatabase.seedIfNeeded(container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch database {
            case .success(let container):
                ThemedRoot()
                    .modelContainer(container)
                    .environment(\.locale, Format.locale)
            case .failure(let error):
                DatabaseErrorView(error: error)
            }
        }
    }
}

/// Показывается, если база данных не открылась. Приложение не падает и ничего
/// не стирает: данные остаются на месте до исправления.
private struct DatabaseErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("База данных не открылась", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Данные не удалены. Не удаляй приложение: пришли этот текст, и проблему можно будет исправить обновлением.\n\n\(String(describing: error))")
        }
    }
}

/// Корень с выбранной темой и первым запуском.
private struct ThemedRoot: View {
    @AppStorage("theme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("onboarding.done") private var onboardingDone = false

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        RootView()
            .tint(theme.accent)
            .preferredColorScheme(theme.colorScheme)
            .sheet(isPresented: Binding(get: { !onboardingDone }, set: { if !$0 { onboardingDone = true } })) {
                OnboardingView { onboardingDone = true }
                    .tint(theme.accent)
            }
    }
}
