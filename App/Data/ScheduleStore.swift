import DayTrackCore
import Foundation
import SwiftData

/// Настройки расписания, которые хранятся вне базы.
enum ScheduleSettings {
    private static let firstWeekKeyName = "schedule.firstWeekKey"

    /// День, с которого считаются учебные недели (неделя с ним — первая, нечётная).
    static var firstWeekKey: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: firstWeekKeyName)
            return stored > 0 ? stored : WeeklySchedule.defaultFirstWeekKey(today: DayClock.app.key(for: .now))
        }
        set { UserDefaults.standard.set(newValue, forKey: firstWeekKeyName) }
    }
}

/// Подстановка расписания и шаблонов в план.
@MainActor
extension DayStore {
    private func categories() -> [ActivityCategory] {
        (try? context.fetch(FetchDescriptor<ActivityCategory>())) ?? []
    }

    /// Правила расписания, действующие в этот день, по времени начала.
    func scheduleRules(for dayKey: Int) -> [ScheduleRule] {
        let rules = (try? context.fetch(FetchDescriptor<ScheduleRule>())) ?? []
        let firstWeek = ScheduleSettings.firstWeekKey
        return rules
            .filter { WeeklySchedule.applies($0.data, on: dayKey, firstWeekKey: firstWeek, calendar: clock.calendar) }
            .sorted { $0.startMinute < $1.startMinute }
    }

    /// Подставляет расписание в день один раз: в сегодняшний или будущий день,
    /// план которого ещё не зафиксирован. Удалённые потом блоки сами не возвращаются.
    func autoApplySchedule(dayKey: Int) {
        guard dayKey >= clock.key(for: .now) else { return }
        if let day = day(forKey: dayKey), day.scheduleApplied || day.isLocked { return }
        guard !scheduleRules(for: dayKey).isEmpty else { return }
        applySchedule(dayKey: dayKey)
    }

    /// Добавляет занятия расписания, которых ещё нет в плане. Возвращает число добавленных.
    @discardableResult
    func applySchedule(dayKey: Int) -> Int {
        let day = ensureDay(forKey: dayKey)
        let all = categories()
        var added = 0
        for rule in scheduleRules(for: dayKey) {
            guard let start = clock.resolve(hour: rule.startMinute / 60, minute: rule.startMinute % 60, inDay: dayKey)
            else { continue }
            let end = clock.end(after: start, hour: rule.endMinute / 60, minute: rule.endMinute % 60)
            let exists = day.activeBlocks.contains { $0.title == rule.title && $0.start == start }
            guard !exists else { continue }
            let block = addBlock(
                dayKey: dayKey, title: rule.title,
                category: all.first { $0.uuid == rule.categoryUUID },
                start: start, end: end, note: ""
            )
            block.sourceRaw = PlannedBlock.Source.schedule.rawValue
            added += 1
        }
        day.scheduleApplied = true
        save()
        return added
    }

    /// Добавляет блоки шаблона в день.
    func applyTemplate(_ template: DayTemplate, dayKey: Int) {
        let all = categories()
        for item in template.items {
            guard let start = clock.resolve(hour: item.startMinute / 60, minute: item.startMinute % 60, inDay: dayKey)
            else { continue }
            let block = addBlock(
                dayKey: dayKey, title: item.title,
                category: all.first { $0.uuid == item.categoryUUID },
                start: start, end: start.addingTimeInterval(Double(item.durationMinutes) * 60), note: ""
            )
            block.sourceRaw = PlannedBlock.Source.template.rawValue
        }
        save()
    }

    /// Сохраняет блоки дня как новый шаблон.
    func saveTemplate(named name: String, from day: Day) {
        let calendar = clock.calendar
        let items = day.activeBlocks.sorted { $0.start < $1.start }.map { block -> TemplateItem in
            let parts = calendar.dateComponents([.hour, .minute], from: block.start)
            return TemplateItem(
                title: block.title,
                categoryUUID: block.category?.uuid,
                startMinute: (parts.hour ?? 0) * 60 + (parts.minute ?? 0),
                durationMinutes: PlanComparison.minutes(from: block.start, to: block.end)
            )
        }
        context.insert(DayTemplate(name: name, items: items))
        save()
    }
}
