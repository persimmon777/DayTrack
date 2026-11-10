import ActivityKit
import Foundation

/// Запуск и остановка таймера отдыха на экране блокировки.
@MainActor
enum RestTimerController {
    enum StartError: LocalizedError {
        case disabledInSettings

        var errorDescription: String? {
            "Live Activity выключены в настройках iPhone для DayTrack"
        }
    }

    static var isAllowed: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static var hasRunningTimer: Bool {
        !Activity<RestTimerAttributes>.activities.isEmpty
    }

    static func start(title: String, duration: TimeInterval) async throws {
        guard isAllowed else { throw StartError.disabledInSettings }
        await stopAll()

        let endDate = Date.now.addingTimeInterval(duration)
        let content = ActivityContent(
            state: RestTimerAttributes.ContentState(endDate: endDate),
            staleDate: endDate
        )
        _ = try Activity<RestTimerAttributes>.request(
            attributes: RestTimerAttributes(title: title),
            content: content,
            pushType: nil
        )
    }

    static func stopAll() async {
        for activity in Activity<RestTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
