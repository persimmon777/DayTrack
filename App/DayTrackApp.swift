import SwiftUI
import UserNotifications

@main
struct DayTrackApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
