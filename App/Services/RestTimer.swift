import DayTrackCore
import Foundation
import SwiftData
import UserNotifications

/// Вид сессии с таймером.
enum SessionMode: String {
    /// Отдых с понятным концом.
    case rest
    /// «Только начать»: несколько минут на большое дело.
    case focus
    /// Игры по таймеру.
    case game

    var symbol: String {
        switch self {
        case .rest: return "cup.and.saucer.fill"
        case .focus: return "figure.walk.motion"
        case .game: return "gamecontroller.fill"
        }
    }

    var title: String {
        switch self {
        case .rest: return "Отдых"
        case .focus: return "Фокус"
        case .game: return "Игра"
        }
    }

    var finishTitle: String {
        switch self {
        case .rest: return "Я вернулся"
        case .focus: return "Закончил"
        case .game: return "Выключил"
        }
    }
}

/// Состояние таймера хранится в UserDefaults, чтобы пережить закрытие приложения.
enum RestTimerKeys {
    static let startedAt = "rest.startedAt"
    static let endsAt = "rest.endsAt"
    static let returnTo = "rest.returnTo"
    static let mode = "rest.mode"
    static let projectUUID = "rest.projectUUID"
}

/// Итог сессии.
struct SessionResult {
    var mode: SessionMode
    var planned: Int
    var actual: Int
    var projectUUID: UUID?
    var stepTitle: String
}

@MainActor
enum RestTimer {
    private static let defaults = UserDefaults.standard
    private static let notificationIDs = ["rest-end", "rest-late", "rest-late2"]

    static var isRunning: Bool { defaults.double(forKey: RestTimerKeys.endsAt) > 0 }

    static var mode: SessionMode {
        SessionMode(rawValue: defaults.string(forKey: RestTimerKeys.mode) ?? "") ?? .rest
    }

    /// Запускает таймер. `label` — к чему вернуться после отдыха или шаг, которым занят в фокусе.
    static func start(mode: SessionMode = .rest, minutes: Int, label: String, projectUUID: UUID? = nil) async {
        let now = Date.now
        let duration = TimeInterval(minutes * 60)
        let end = now.addingTimeInterval(duration)
        defaults.set(now.timeIntervalSince1970, forKey: RestTimerKeys.startedAt)
        defaults.set(end.timeIntervalSince1970, forKey: RestTimerKeys.endsAt)
        defaults.set(label, forKey: RestTimerKeys.returnTo)
        defaults.set(mode.rawValue, forKey: RestTimerKeys.mode)
        defaults.set(projectUUID?.uuidString, forKey: RestTimerKeys.projectUUID)

        let activityTitle: String
        switch mode {
        case .rest: activityTitle = label.isEmpty ? "Отдых" : "Отдых · потом: \(label)"
        case .focus: activityTitle = label.isEmpty ? "Только начать" : label
        case .game: activityTitle = "Игра по таймеру"
        }
        try? await RestTimerController.start(title: activityTitle, duration: duration)

        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        center.removePendingNotificationRequests(withIdentifiers: notificationIDs)
        func schedule(_ id: String, after seconds: TimeInterval, title: String, body: String) async {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        switch mode {
        case .rest:
            let next = label.isEmpty ? "к делам" : "к «\(label)»"
            await schedule("rest-end", after: duration, title: "Отдых закончился",
                           body: "Возвращайся \(next). Начни с самого маленького шага.")
            await schedule("rest-late", after: duration + 10 * 60, title: "Отдых затянулся на 10 минут",
                           body: "Ничего страшного. Нажми «Я вернулся», когда приступишь \(next).")
        case .focus:
            await schedule("rest-end", after: duration, title: "\(minutes) минут прошли",
                           body: "Ты начал — это самое трудное. Можно остановиться с чистой совестью, а можно продолжить, пока идёт.")
        case .game:
            await schedule("rest-end", after: duration, title: "Игровое время вышло",
                           body: "Сохранись и выходи: это время ты сам себе выделил, и оно закончилось.")
            await schedule("rest-late", after: duration + 10 * 60, title: "Уже на 10 минут дольше",
                           body: "«Ещё одна катка» — ловушка: игры устроены так, чтобы не было удобного места остановиться. Сохранись прямо сейчас.")
            await schedule("rest-late2", after: duration + 30 * 60, title: "Полчаса сверх плана",
                           body: "Отложи телефон или геймпад в другую комнату. Нажми «Выключил», и время запишется как есть, без упрёков.")
        }
    }

    /// Завершает сессию и записывает её в факт с реальной длительностью.
    @discardableResult
    static func finish(context: ModelContext) async -> SessionResult? {
        guard isRunning else { return nil }
        let mode = self.mode
        let start = Date(timeIntervalSince1970: defaults.double(forKey: RestTimerKeys.startedAt))
        let plannedEnd = Date(timeIntervalSince1970: defaults.double(forKey: RestTimerKeys.endsAt))
        let label = defaults.string(forKey: RestTimerKeys.returnTo) ?? ""
        let projectUUID = defaults.string(forKey: RestTimerKeys.projectUUID).flatMap(UUID.init(uuidString:))
        let end = Date.now
        clear()
        await RestTimerController.stopAll()

        let result = SessionResult(
            mode: mode,
            planned: PlanComparison.minutes(from: start, to: plannedEnd),
            actual: PlanComparison.minutes(from: start, to: end),
            projectUUID: projectUUID,
            stepTitle: label
        )
        guard result.actual >= 1 else { return result }

        let clock = DayClock.app
        let dayKey = clock.key(for: start)
        let store = DayStore(context: context)
        let categories = (try? context.fetch(FetchDescriptor<ActivityCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let blocks = store.day(forKey: dayKey)?.activeBlocks ?? []

        func overlapping(_ predicate: (PlannedBlock) -> Bool) -> PlannedBlock? {
            blocks.filter(predicate)
                .max { overlap($0, start, end) < overlap($1, start, end) }
                .flatMap { overlap($0, start, end) > 0 ? $0 : nil }
        }

        switch mode {
        case .rest:
            let block = overlapping { $0.category?.kind == .rest }
            let rest = categories.first { $0.kind == .rest && !$0.isArchived }
            store.addFact(dayKey: dayKey, block: block, title: block?.title ?? "Отдых", category: block?.category ?? rest,
                          start: start, end: end, reason: block == nil ? .other : nil, note: "")
        case .game:
            let games = AppDatabase.gamesCategory(context)
            let block = overlapping { $0.category?.uuid == games.uuid }
            store.addFact(dayKey: dayKey, block: block, title: block?.title ?? "Игры", category: games,
                          start: start, end: end, reason: block == nil ? .other : nil, note: "")
        case .focus:
            let project = projectUUID.flatMap { id in
                (try? context.fetch(FetchDescriptor<Project>()))?.first { $0.uuid == id }
            }
            let category = categories.first { $0.uuid == project?.categoryUUID }
                ?? categories.first { $0.kind == .study && !$0.isArchived }
            let block = overlapping { $0.category?.uuid == category?.uuid }
            let title = project.map { label.isEmpty ? $0.title : "\($0.title): \(label)" } ?? (label.isEmpty ? "Фокус" : label)
            let fact = store.addFact(dayKey: dayKey, block: block, title: title, category: category,
                                     start: start, end: end, reason: block == nil ? .other : nil, note: "")
            fact.projectUUID = project?.uuid
            project?.lastWorkedAt = end
            store.save()
        }
        return result
    }

    static func cancel() async {
        clear()
        await RestTimerController.stopAll()
    }

    private static func clear() {
        defaults.removeObject(forKey: RestTimerKeys.startedAt)
        defaults.set(0.0, forKey: RestTimerKeys.endsAt)
        defaults.removeObject(forKey: RestTimerKeys.returnTo)
        defaults.removeObject(forKey: RestTimerKeys.mode)
        defaults.removeObject(forKey: RestTimerKeys.projectUUID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIDs)
    }

    private static func overlap(_ block: PlannedBlock, _ start: Date, _ end: Date) -> TimeInterval {
        min(end, block.end).timeIntervalSince(max(start, block.start))
    }
}

/// Бюджет игрового времени.
enum GameSettings {
    private static let defaults = UserDefaults.standard

    /// Сколько минут игр в неделю считать нормой.
    static var weeklyBudgetMinutes: Int {
        get { defaults.object(forKey: "games.budget") as? Int ?? 7 * 60 }
        set { defaults.set(newValue, forKey: "games.budget") }
    }

    /// Игровое время зарабатывается учёбой: минута учёбы — минута игры.
    static var earnByStudy: Bool {
        get { defaults.bool(forKey: "games.earn") }
        set { defaults.set(newValue, forKey: "games.earn") }
    }

    /// Сыграно и выучено за текущую неделю.
    @MainActor
    static func weekStats(context: ModelContext) -> (played: Int, studied: Int) {
        let calendar = Calendar.current
        let week = Periods.range(.week, containing: DayClock.app.key(for: .now), calendar: calendar)
        let from = week.lowerBound, to = week.upperBound
        let days = (try? context.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.key >= from && $0.key <= to }))) ?? []
        let games = AppDatabase.gamesCategory(context).uuid
        var played = 0, studied = 0
        for fact in days.flatMap(\.facts) {
            let minutes = PlanComparison.minutes(from: fact.start, to: fact.end)
            if fact.category?.uuid == games { played += minutes }
            else if fact.category?.kind == .study { studied += minutes }
        }
        return (played, studied)
    }

    /// Сколько ещё можно играть на этой неделе.
    @MainActor
    static func remaining(context: ModelContext) -> Int {
        let stats = weekStats(context: context)
        let allowance = earnByStudy ? min(stats.studied, weeklyBudgetMinutes) : weeklyBudgetMinutes
        return max(allowance - stats.played, 0)
    }
}
