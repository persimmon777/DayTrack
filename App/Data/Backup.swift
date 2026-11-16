import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Полная копия данных в JSON. Поля только добавляются, поэтому копии
/// старых версий читаются новыми.
struct BackupSnapshot: Codable {
    var formatVersion = 1
    var exportedAt: Date
    var appVersion: String
    var firstWeekKey: Int?
    var categories: [CategoryDTO]
    var days: [DayDTO]
    var reminders: [ReminderDTO]
    var scheduleRules: [ScheduleRuleDTO]
    var templates: [TemplateDTO]
    var focuses: [FocusDTO]?
    var energyMarks: [EnergyDTO]?
    var reflections: [ReflectionDTO]?

    struct FocusDTO: Codable {
        var uuid: UUID, title: String, why: String, periodRaw: String, periodStartKey: Int
        var parentUUID: UUID?, statusRaw: String, result: String, sortOrder: Int, createdAt: Date
    }
    struct EnergyDTO: Codable {
        var uuid: UUID, at: Date, dayKey: Int, energy: Int, mood: Int
    }
    struct ReflectionDTO: Codable {
        var dayKey: Int, wentWell: String, hindered: String, changeTomorrow: String, rating: Int, updatedAt: Date
    }

    struct CategoryDTO: Codable {
        var uuid: UUID, name: String, colorHex: String, symbol: String, kindRaw: String
        var sortOrder: Int, isArchived: Bool, keywordsRaw: String?
    }
    struct DayDTO: Codable {
        var key: Int, lockedAt: Date?, planEditedAt: Date?, scheduleApplied: Bool?
        var blocks: [BlockDTO], tasks: [TaskDTO], facts: [FactDTO], changes: [ChangeDTO]
    }
    struct BlockDTO: Codable {
        var uuid: UUID, title: String, start: Date, end: Date, note: String
        var baselineStart: Date?, baselineEnd: Date?, addedAfterLock: Bool, removedAt: Date?
        var missReasonRaw: String?, sourceRaw: String?, categoryUUID: UUID?, focusUUID: UUID?, isFrog: Bool?
    }
    struct TaskDTO: Codable {
        var uuid: UUID, title: String, estimateMinutes: Int, isDone: Bool, sortOrder: Int
        var createdAt: Date, addedAfterLock: Bool, categoryUUID: UUID?, focusUUID: UUID?
    }
    struct FactDTO: Codable {
        var uuid: UUID, title: String, start: Date, end: Date, note: String
        var reasonRaw: String?, categoryUUID: UUID?, blockUUID: UUID?, focusUUID: UUID?
    }
    struct ChangeDTO: Codable {
        var uuid: UUID, at: Date, kindRaw: String, text: String, blockUUID: UUID?
    }
    struct ReminderDTO: Codable {
        var uuid: UUID, title: String, note: String, firstDayKey: Int, minuteOfDay: Int?
        var repeatRaw: String, notify: Bool, leadDays: Int, createdAt: Date
    }
    struct ScheduleRuleDTO: Codable {
        var uuid: UUID, title: String, categoryUUID: UUID?, weekday: Int
        var startMinute: Int, endMinute: Int, parityRaw: String
        var validFromKey: Int?, validUntilKey: Int?, isEnabled: Bool
    }
    struct TemplateDTO: Codable {
        var uuid: UUID, name: String, itemsJSON: String, createdAt: Date
    }

    var summary: String {
        let facts = days.reduce(0) { $0 + $1.facts.count }
        return "Дней: \(days.count), записей факта: \(facts), напоминаний: \(reminders.count)"
    }
}

@MainActor
enum BackupService {
    // MARK: Снимок и восстановление

    static func makeSnapshot(context: ModelContext) -> BackupSnapshot {
        func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? context.fetch(FetchDescriptor<T>())) ?? []
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

        return BackupSnapshot(
            exportedAt: .now,
            appVersion: version,
            firstWeekKey: ScheduleSettings.firstWeekKey,
            categories: fetch(ActivityCategory.self).map {
                .init(uuid: $0.uuid, name: $0.name, colorHex: $0.colorHex, symbol: $0.symbol, kindRaw: $0.kindRaw,
                      sortOrder: $0.sortOrder, isArchived: $0.isArchived, keywordsRaw: $0.keywordsRaw)
            },
            days: fetch(Day.self).sorted { $0.key < $1.key }.map { day in
                .init(
                    key: day.key, lockedAt: day.lockedAt, planEditedAt: day.planEditedAt,
                    scheduleApplied: day.scheduleApplied,
                    blocks: day.blocks.map {
                        .init(uuid: $0.uuid, title: $0.title, start: $0.start, end: $0.end, note: $0.note,
                              baselineStart: $0.baselineStart, baselineEnd: $0.baselineEnd,
                              addedAfterLock: $0.addedAfterLock, removedAt: $0.removedAt,
                              missReasonRaw: $0.missReasonRaw, sourceRaw: $0.sourceRaw,
                              categoryUUID: $0.category?.uuid, focusUUID: $0.focusUUID, isFrog: $0.isFrog)
                    },
                    tasks: day.tasks.map {
                        .init(uuid: $0.uuid, title: $0.title, estimateMinutes: $0.estimateMinutes, isDone: $0.isDone,
                              sortOrder: $0.sortOrder, createdAt: $0.createdAt, addedAfterLock: $0.addedAfterLock,
                              categoryUUID: $0.category?.uuid, focusUUID: $0.focusUUID)
                    },
                    facts: day.facts.map {
                        .init(uuid: $0.uuid, title: $0.title, start: $0.start, end: $0.end, note: $0.note,
                              reasonRaw: $0.reasonRaw, categoryUUID: $0.category?.uuid, blockUUID: $0.block?.uuid,
                              focusUUID: $0.focusUUID)
                    },
                    changes: day.changes.map {
                        .init(uuid: $0.uuid, at: $0.at, kindRaw: $0.kindRaw, text: $0.text, blockUUID: $0.blockUUID)
                    }
                )
            },
            reminders: fetch(Reminder.self).map {
                .init(uuid: $0.uuid, title: $0.title, note: $0.note, firstDayKey: $0.firstDayKey,
                      minuteOfDay: $0.minuteOfDay, repeatRaw: $0.repeatRaw, notify: $0.notify,
                      leadDays: $0.leadDays, createdAt: $0.createdAt)
            },
            scheduleRules: fetch(ScheduleRule.self).map {
                .init(uuid: $0.uuid, title: $0.title, categoryUUID: $0.categoryUUID, weekday: $0.weekday,
                      startMinute: $0.startMinute, endMinute: $0.endMinute, parityRaw: $0.parityRaw,
                      validFromKey: $0.validFromKey, validUntilKey: $0.validUntilKey, isEnabled: $0.isEnabled)
            },
            templates: fetch(DayTemplate.self).map {
                .init(uuid: $0.uuid, name: $0.name, itemsJSON: $0.itemsJSON, createdAt: $0.createdAt)
            },
            focuses: fetch(Focus.self).map {
                .init(uuid: $0.uuid, title: $0.title, why: $0.why, periodRaw: $0.periodRaw,
                      periodStartKey: $0.periodStartKey, parentUUID: $0.parentUUID, statusRaw: $0.statusRaw,
                      result: $0.result, sortOrder: $0.sortOrder, createdAt: $0.createdAt)
            },
            energyMarks: fetch(EnergyMark.self).map {
                .init(uuid: $0.uuid, at: $0.at, dayKey: $0.dayKey, energy: $0.energy, mood: $0.mood)
            },
            reflections: fetch(Reflection.self).map {
                .init(dayKey: $0.dayKey, wentWell: $0.wentWell, hindered: $0.hindered,
                      changeTomorrow: $0.changeTomorrow, rating: $0.rating, updatedAt: $0.updatedAt)
            }
        )
    }

    /// Заменяет все данные содержимым копии.
    static func restore(_ snapshot: BackupSnapshot, context: ModelContext) throws {
        func deleteAll<T: PersistentModel>(_ type: T.Type) {
            for item in (try? context.fetch(FetchDescriptor<T>())) ?? [] { context.delete(item) }
        }
        deleteAll(PlanChange.self)
        deleteAll(FactEntry.self)
        deleteAll(TaskItem.self)
        deleteAll(PlannedBlock.self)
        deleteAll(Day.self)
        deleteAll(ActivityCategory.self)
        deleteAll(Reminder.self)
        deleteAll(ScheduleRule.self)
        deleteAll(DayTemplate.self)
        deleteAll(Focus.self)
        deleteAll(EnergyMark.self)
        deleteAll(Reflection.self)
        try context.save()

        var categories: [UUID: ActivityCategory] = [:]
        for dto in snapshot.categories {
            let category = ActivityCategory(name: dto.name, colorHex: dto.colorHex, symbol: dto.symbol,
                                            kind: .other, sortOrder: dto.sortOrder)
            category.uuid = dto.uuid
            category.kindRaw = dto.kindRaw
            category.isArchived = dto.isArchived
            category.keywordsRaw = dto.keywordsRaw ?? ""
            context.insert(category)
            categories[dto.uuid] = category
        }

        for dto in snapshot.days {
            let day = Day(key: dto.key)
            day.lockedAt = dto.lockedAt
            day.planEditedAt = dto.planEditedAt
            day.scheduleApplied = dto.scheduleApplied ?? false
            context.insert(day)

            var blocks: [UUID: PlannedBlock] = [:]
            for item in dto.blocks {
                let block = PlannedBlock(title: item.title, start: item.start, end: item.end, note: item.note)
                block.uuid = item.uuid
                block.baselineStart = item.baselineStart
                block.baselineEnd = item.baselineEnd
                block.addedAfterLock = item.addedAfterLock
                block.removedAt = item.removedAt
                block.missReasonRaw = item.missReasonRaw
                block.sourceRaw = item.sourceRaw ?? PlannedBlock.Source.manual.rawValue
                block.focusUUID = item.focusUUID
                block.isFrog = item.isFrog ?? false
                context.insert(block)
                block.day = day
                block.category = item.categoryUUID.flatMap { categories[$0] }
                blocks[item.uuid] = block
            }
            for item in dto.tasks {
                let task = TaskItem(title: item.title, sortOrder: item.sortOrder, createdAt: item.createdAt)
                task.uuid = item.uuid
                task.estimateMinutes = item.estimateMinutes
                task.isDone = item.isDone
                task.addedAfterLock = item.addedAfterLock
                task.focusUUID = item.focusUUID
                context.insert(task)
                task.day = day
                task.category = item.categoryUUID.flatMap { categories[$0] }
            }
            for item in dto.facts {
                let fact = FactEntry(title: item.title, start: item.start, end: item.end, note: item.note)
                fact.uuid = item.uuid
                fact.reasonRaw = item.reasonRaw
                fact.focusUUID = item.focusUUID
                context.insert(fact)
                fact.day = day
                fact.category = item.categoryUUID.flatMap { categories[$0] }
                fact.block = item.blockUUID.flatMap { blocks[$0] }
            }
            for item in dto.changes {
                let change = PlanChange(kind: .edited, text: item.text, blockUUID: item.blockUUID, at: item.at)
                change.uuid = item.uuid
                change.kindRaw = item.kindRaw
                context.insert(change)
                change.day = day
            }
        }

        for dto in snapshot.reminders {
            let reminder = Reminder(title: dto.title, firstDayKey: dto.firstDayKey)
            reminder.uuid = dto.uuid
            reminder.note = dto.note
            reminder.minuteOfDay = dto.minuteOfDay
            reminder.repeatRaw = dto.repeatRaw
            reminder.notify = dto.notify
            reminder.leadDays = dto.leadDays
            reminder.createdAt = dto.createdAt
            context.insert(reminder)
        }
        for dto in snapshot.scheduleRules {
            let rule = ScheduleRule(title: dto.title, weekday: dto.weekday)
            rule.uuid = dto.uuid
            rule.categoryUUID = dto.categoryUUID
            rule.startMinute = dto.startMinute
            rule.endMinute = dto.endMinute
            rule.parityRaw = dto.parityRaw
            rule.validFromKey = dto.validFromKey
            rule.validUntilKey = dto.validUntilKey
            rule.isEnabled = dto.isEnabled
            context.insert(rule)
        }
        for dto in snapshot.templates {
            let template = DayTemplate(name: dto.name, items: [])
            template.uuid = dto.uuid
            template.itemsJSON = dto.itemsJSON
            template.createdAt = dto.createdAt
            context.insert(template)
        }
        for dto in snapshot.focuses ?? [] {
            let focus = Focus(title: dto.title, period: .week, periodStartKey: dto.periodStartKey)
            focus.uuid = dto.uuid
            focus.why = dto.why
            focus.periodRaw = dto.periodRaw
            focus.parentUUID = dto.parentUUID
            focus.statusRaw = dto.statusRaw
            focus.result = dto.result
            focus.sortOrder = dto.sortOrder
            focus.createdAt = dto.createdAt
            context.insert(focus)
        }
        for dto in snapshot.energyMarks ?? [] {
            let mark = EnergyMark(at: dto.at, dayKey: dto.dayKey, energy: dto.energy, mood: dto.mood)
            mark.uuid = dto.uuid
            context.insert(mark)
        }
        for dto in snapshot.reflections ?? [] {
            let reflection = Reflection(dayKey: dto.dayKey)
            reflection.wentWell = dto.wentWell
            reflection.hindered = dto.hindered
            reflection.changeTomorrow = dto.changeTomorrow
            reflection.rating = dto.rating
            reflection.updatedAt = dto.updatedAt
            context.insert(reflection)
        }
        if let key = snapshot.firstWeekKey { ScheduleSettings.firstWeekKey = key }
        try context.save()
    }

    // MARK: Файлы

    static func encode(_ snapshot: BackupSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    static func decode(_ data: Data) throws -> BackupSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupSnapshot.self, from: data)
    }

    static func fileName(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "DayTrack-\(formatter.string(from: date)).json"
    }

    // MARK: Автокопия в выбранную папку

    private static let bookmarkKey = "backup.folderBookmark"
    private static let lastBackupKey = "backup.lastDate"
    private static let keepCount = 14

    static var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: lastBackupKey) as? Date
    }

    static var folderName: String? {
        resolveFolder()?.lastPathComponent
    }

    static func setFolder(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    }

    static func clearFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    private static func resolveFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
        else { return nil }
        if isStale { try? setFolder(url) }
        return url
    }

    /// Записывает копию в выбранную папку и удаляет самые старые, оставляя 14.
    @discardableResult
    static func writeToFolder(context: ModelContext) throws -> String {
        guard let folder = resolveFolder() else { throw BackupError.noFolder }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }

        let data = try encode(makeSnapshot(context: context))
        let name = fileName()
        try data.write(to: folder.appendingPathComponent(name), options: .atomic)
        UserDefaults.standard.set(Date.now, forKey: lastBackupKey)

        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let backups = files
            .filter { $0.lastPathComponent.hasPrefix("DayTrack-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in backups.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: old)
        }
        return name
    }

    /// Раз в сутки при открытии приложения.
    static func autoBackupIfNeeded(context: ModelContext) {
        guard resolveFolder() != nil else { return }
        if let last = lastBackupDate, Calendar.current.isDateInToday(last) { return }
        try? writeToFolder(context: context)
    }

    enum BackupError: LocalizedError {
        case noFolder
        var errorDescription: String? { "Папка для копий не выбрана" }
    }
}

/// Файл копии для сохранения через системное окно.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
