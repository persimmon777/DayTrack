import UserNotifications

/// Показывает уведомления, даже когда приложение открыто.
/// Без этого iOS молча скрывает уведомление, пришедшее при открытом приложении.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    /// Центр уведомлений держит на делегата слабую ссылку, поэтому он живёт здесь.
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
