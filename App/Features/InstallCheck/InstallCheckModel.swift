import Foundation
import Observation
import UIKit
import UserNotifications
import WidgetKit

/// Состояние экрана проверки установки (этап 0).
@MainActor
@Observable
final class InstallCheckModel {
    enum Outcome: Equatable {
        case notRun
        case ok(String)
        case failed(String)
    }

    let container = SharedContainer.resolution

    var number = Int.random(in: 10...99)
    var writeOutcome: Outcome = .notRun
    var widgetAck: InstallCheckAck?
    var placedWidgetCount: Int?
    var timerOutcome: Outcome = .notRun
    var notificationOutcome: Outcome = .notRun
    var notificationStatus = "не проверено"
    var copied = false

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (сборка \(build))"
    }

    /// Виджет подтвердил, что прочитал именно то число, которое записано сейчас.
    var widgetConfirmed: Bool {
        guard case .ok = writeOutcome, let widgetAck else { return false }
        return widgetAck.number == number
    }

    // MARK: Общая папка и виджет

    func writeNumber() {
        number = Int.random(in: 100...999)
        do {
            try InstallCheckStore.writeSnapshot(InstallCheckSnapshot(number: number, writtenAt: .now))
            writeOutcome = .ok("Записано число \(number)")
        } catch {
            writeOutcome = .failed("Не удалось записать: общая папка недоступна")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func refresh() async {
        widgetAck = InstallCheckStore.readAck()
        placedWidgetCount = await placedWidgets()
        notificationStatus = await currentNotificationStatus()
    }

    private func placedWidgets() async -> Int? {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                continuation.resume(returning: (try? result.get())?.count)
            }
        }
    }

    // MARK: Таймер на экране блокировки

    func startTimer() async {
        do {
            try await RestTimerController.start(title: "Проверка таймера", duration: 60)
            timerOutcome = .ok("Таймер на 1 минуту запущен. Заблокируй телефон и посмотри на экран блокировки")
        } catch {
            timerOutcome = .failed("Не запустился: \(error.localizedDescription)")
        }
    }

    func stopTimer() async {
        await RestTimerController.stopAll()
        timerOutcome = .notRun
    }

    // MARK: Уведомления

    func sendNotification() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            notificationStatus = await currentNotificationStatus()
            guard granted else {
                notificationOutcome = .failed("Уведомления запрещены. Разреши их в настройках iPhone для DayTrack")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "DayTrack"
            content.body = "Тестовое уведомление пришло. Проверка пройдена."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            let request = UNNotificationRequest(
                identifier: "install-check",
                content: content,
                trigger: trigger
            )
            try await center.add(request)
            notificationOutcome = .ok("Придёт через 10 секунд. Можно свернуть приложение или заблокировать телефон")
        } catch {
            notificationOutcome = .failed("Ошибка: \(error.localizedDescription)")
        }
    }

    private func currentNotificationStatus() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: return "разрешены"
        case .denied: return "запрещены"
        case .notDetermined: return "ещё не спрашивали"
        case .provisional: return "разрешены временно"
        case .ephemeral: return "разрешены на время"
        @unknown default: return "неизвестно"
        }
    }

    // MARK: Отчёт о проверке

    var report: String {
        func text(_ outcome: Outcome) -> String {
            switch outcome {
            case .notRun: return "не запускалось"
            case .ok(let message): return "ок — \(message)"
            case .failed(let message): return "ОШИБКА — \(message)"
            }
        }
        func list(_ items: [String]) -> String {
            items.isEmpty ? "нет" : items.joined(separator: ", ")
        }

        var lines: [String] = []
        lines.append("DayTrack \(appVersion)")
        lines.append("iOS \(UIDevice.current.systemVersion), \(Self.deviceModel)")
        lines.append("")
        lines.append("Идентификатор приложения: \(container.bundleID)")
        lines.append("Профиль подписи: \(container.profileFound ? "найден" : "не найден")")
        lines.append("Группы в профиле: \(list(container.profileGroups))")
        lines.append("Проверенные группы: \(list(container.candidates))")
        lines.append("Общая папка: \(container.groupID ?? "НЕДОСТУПНА")")
        lines.append("")
        lines.append("Запись числа: \(text(writeOutcome))")
        if let widgetAck {
            let time = widgetAck.readAt.formatted(date: .omitted, time: .standard)
            lines.append("Виджет прочитал: \(widgetAck.number) в \(time)")
        } else {
            lines.append("Виджет прочитал: ничего")
        }
        lines.append("Виджетов на экране: \(placedWidgetCount.map { "\($0)" } ?? "неизвестно")")
        lines.append("")
        lines.append("Live Activity разрешены: \(RestTimerController.isAllowed ? "да" : "нет")")
        lines.append("Таймер: \(text(timerOutcome))")
        lines.append("")
        lines.append("Уведомления: \(notificationStatus)")
        lines.append("Тестовое уведомление: \(text(notificationOutcome))")
        return lines.joined(separator: "\n")
    }

    func copyReport() {
        UIPasteboard.general.string = report
        copied = true
    }

    private static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}
