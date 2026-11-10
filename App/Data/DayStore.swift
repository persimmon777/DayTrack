import DayTrackCore
import Foundation
import SwiftData

/// Все изменения дня проходят через этот тип: здесь соблюдаются правила фиксации
/// плана и ведётся журнал правок.
@MainActor
struct DayStore {
    let context: ModelContext
    var clock: DayClock = .app

    // MARK: День

    func day(forKey key: Int) -> Day? {
        var descriptor = FetchDescriptor<Day>(predicate: #Predicate<Day> { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func ensureDay(forKey key: Int) -> Day {
        if let existing = day(forKey: key) { return existing }
        let day = Day(key: key)
        context.insert(day)
        return day
    }

    func save() {
        try? context.save()
    }

    // MARK: Фиксация плана

    /// Фиксирует план: запоминает исходное время каждого блока.
    func lock(_ day: Day, at date: Date = .now) {
        guard !day.isLocked else { return }
        day.lockedAt = date
        for block in day.blocks {
            block.baselineStart = block.start
            block.baselineEnd = block.end
            block.addedAfterLock = false
        }
        for task in day.tasks {
            task.addedAfterLock = false
        }
        save()
    }

    /// Снять фиксацию можно, пока не внесён факт: после этого сравнивать было бы не с чем.
    func canUnlock(_ day: Day) -> Bool {
        day.isLocked && day.facts.isEmpty
    }

    func unlock(_ day: Day) {
        guard canUnlock(day) else { return }
        // Списки копируются заранее: удалять записи во время обхода связи нельзя.
        let removed = day.blocks.filter { $0.removedAt != nil }
        let kept = day.blocks.filter { $0.removedAt == nil }
        let changes = day.changes
        for block in kept {
            block.baselineStart = nil
            block.baselineEnd = nil
            block.addedAfterLock = false
        }
        for task in day.tasks {
            task.addedAfterLock = false
        }
        for block in removed { context.delete(block) }
        for change in changes { context.delete(change) }
        day.lockedAt = nil
        day.planEditedAt = .now
        save()
    }

    /// Сколько план должен оставаться нетронутым, прежде чем зафиксируется сам.
    /// Без этой паузы план фиксировался бы посреди составления, если первый
    /// блок уже начался.
    static let autoLockQuietInterval: TimeInterval = 15 * 60

    /// Фиксирует план сам, когда наступило время первого блока.
    func autoLockIfNeeded(dayKey: Int, now: Date = .now) {
        guard let day = day(forKey: dayKey), !day.isLocked, !day.blocks.isEmpty else { return }
        guard let firstStart = day.blocks.map(\.start).min(), firstStart <= now else { return }
        if let editedAt = day.planEditedAt, now.timeIntervalSince(editedAt) < Self.autoLockQuietInterval {
            return
        }
        lock(day, at: now)
    }

    // MARK: Блоки плана

    @discardableResult
    func addBlock(
        dayKey: Int, title: String, category: ActivityCategory?,
        start: Date, end: Date, note: String
    ) -> PlannedBlock {
        let day = ensureDay(forKey: dayKey)
        let block = PlannedBlock(title: title, start: start, end: end, note: note)
        context.insert(block)
        block.day = day
        block.category = category
        if day.isLocked {
            block.addedAfterLock = true
            log(.added, "Добавлен блок «\(title)» \(Format.timeRange(start, end))", block: block, day: day)
        } else {
            day.planEditedAt = .now
        }
        save()
        return block
    }

    func updateBlock(
        _ block: PlannedBlock, title: String, category: ActivityCategory?,
        start: Date, end: Date, note: String
    ) {
        if let day = block.day, day.isLocked {
            var parts: [String] = []
            if block.start != start || block.end != end {
                parts.append("\(Format.timeRange(block.start, block.end)) → \(Format.timeRange(start, end))")
            }
            if block.title != title {
                parts.append("новое название «\(title)»")
            }
            if block.category?.uuid != category?.uuid {
                parts.append("категория \(block.category?.name ?? "без категории") → \(category?.name ?? "без категории")")
            }
            if !parts.isEmpty {
                log(.edited, "«\(block.title)»: \(parts.joined(separator: ", "))", block: block, day: day)
            }
        }
        block.title = title
        block.category = category
        block.start = start
        block.end = end
        block.note = note
        if let day = block.day, !day.isLocked { day.planEditedAt = .now }
        save()
    }

    /// Удаляет блок. Блок исходного плана после фиксации не стирается, а помечается
    /// удалённым: он нужен для сравнения с исходным планом.
    func deleteBlock(_ block: PlannedBlock) {
        if let day = block.day, day.isLocked {
            log(
                .removed,
                "Удалён блок «\(block.title)» \(Format.timeRange(block.start, block.end))",
                block: block,
                day: day
            )
            if block.isInBaseline {
                block.removedAt = .now
                save()
                return
            }
        }
        if let day = block.day, !day.isLocked { day.planEditedAt = .now }
        context.delete(block)
        save()
    }

    func markMissed(_ block: PlannedBlock, reason: DeviationReason?) {
        block.missReason = reason
        save()
    }

    private func log(_ kind: PlanChangeKind, _ text: String, block: PlannedBlock, day: Day) {
        let change = PlanChange(kind: kind, text: text, blockUUID: block.uuid)
        context.insert(change)
        change.day = day
    }

    // MARK: Факт

    /// Вносит запись факта. Первая запись означает, что день начался, поэтому
    /// план фиксируется, если этого ещё не сделали. Пустой план не фиксируется:
    /// иначе факт, внесённый утром до планирования, закрыл бы возможность
    /// спокойно составить план.
    @discardableResult
    func addFact(
        dayKey: Int, block: PlannedBlock?, title: String, category: ActivityCategory?,
        start: Date, end: Date, reason: DeviationReason?, note: String
    ) -> FactEntry {
        let day = ensureDay(forKey: dayKey)
        if !day.isLocked, !day.blocks.isEmpty { lock(day) }

        let fact = FactEntry(title: title, start: start, end: end, note: note)
        context.insert(fact)
        fact.day = day
        fact.category = category
        fact.block = block
        fact.reason = reason
        // Раз по блоку есть факт, отметка «не сделал» больше не нужна.
        block?.missReason = nil
        save()
        return fact
    }

    func updateFact(
        _ fact: FactEntry, title: String, category: ActivityCategory?,
        start: Date, end: Date, reason: DeviationReason?, note: String
    ) {
        fact.title = title
        fact.category = category
        fact.start = start
        fact.end = end
        fact.reason = reason
        fact.note = note
        save()
    }

    func deleteFact(_ fact: FactEntry) {
        context.delete(fact)
        save()
    }

    // MARK: Задачи без времени

    func addTask(dayKey: Int, title: String) {
        let day = ensureDay(forKey: dayKey)
        let nextOrder = (day.tasks.map(\.sortOrder).max() ?? -1) + 1
        let task = TaskItem(title: title, sortOrder: nextOrder)
        context.insert(task)
        task.day = day
        task.addedAfterLock = day.isLocked
        save()
    }

    func toggleTask(_ task: TaskItem) {
        task.isDone.toggle()
        save()
    }

    func deleteTask(_ task: TaskItem) {
        context.delete(task)
        save()
    }
}
