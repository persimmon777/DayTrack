import DayTrackCore
import Foundation
import SwiftData

// Перечисления хранятся строками (`...Raw`), а не напрямую: так база спокойно
// переживает появление новых значений в следующих версиях приложения.

/// Категория дел: «Учёба», «Отдых», «Сон» и так далее.
@Model
final class ActivityCategory {
    var uuid: UUID = UUID()
    var name: String = ""
    var colorHex: String = "5B8DEF"
    var symbol: String = "circle.fill"
    var kindRaw: String = CategoryKind.other.rawValue
    var sortOrder: Int = 0
    var isArchived: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \PlannedBlock.category)
    var blocks: [PlannedBlock] = []
    @Relationship(deleteRule: .nullify, inverse: \FactEntry.category)
    var facts: [FactEntry] = []
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.category)
    var tasks: [TaskItem] = []

    init(name: String, colorHex: String, symbol: String, kind: CategoryKind, sortOrder: Int) {
        self.uuid = UUID()
        self.name = name
        self.colorHex = colorHex
        self.symbol = symbol
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
    }

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var isInUse: Bool {
        !blocks.isEmpty || !facts.isEmpty || !tasks.isEmpty
    }
}

/// Один день: его план, задачи, факт и журнал правок.
@Model
final class Day {
    /// Ключ дня вида 20261110, см. `DayClock`.
    @Attribute(.unique) var key: Int = 0
    /// Когда план зафиксирован. `nil` — план ещё черновик.
    var lockedAt: Date?
    /// Когда черновик плана меняли в последний раз.
    var planEditedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PlannedBlock.day)
    var blocks: [PlannedBlock] = []
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.day)
    var tasks: [TaskItem] = []
    @Relationship(deleteRule: .cascade, inverse: \FactEntry.day)
    var facts: [FactEntry] = []
    @Relationship(deleteRule: .cascade, inverse: \PlanChange.day)
    var changes: [PlanChange] = []

    init(key: Int) {
        self.key = key
    }

    var isLocked: Bool { lockedAt != nil }

    /// Блоки действующего плана, без удалённых после фиксации.
    var activeBlocks: [PlannedBlock] {
        blocks.filter { $0.removedAt == nil }
    }
}

/// Блок плана на шкале времени.
@Model
final class PlannedBlock {
    var uuid: UUID = UUID()
    var title: String = ""
    var start: Date = Date.distantPast
    var end: Date = Date.distantPast
    var note: String = ""

    /// Время блока в момент фиксации плана. `nil` — блока в исходном плане не было.
    var baselineStart: Date?
    var baselineEnd: Date?
    /// Блок добавлен уже после фиксации.
    var addedAfterLock: Bool = false
    /// Блок удалён после фиксации. Он остаётся в базе, чтобы исходный план не терялся.
    var removedAt: Date?
    /// Причина, если блок отмечен несделанным.
    var missReasonRaw: String?

    var day: Day?
    var category: ActivityCategory?

    @Relationship(deleteRule: .nullify, inverse: \FactEntry.block)
    var facts: [FactEntry] = []

    init(title: String, start: Date, end: Date, note: String = "") {
        self.uuid = UUID()
        self.title = title
        self.start = start
        self.end = end
        self.note = note
    }

    var missReason: DeviationReason? {
        get { missReasonRaw.flatMap(DeviationReason.init(rawValue:)) }
        set { missReasonRaw = newValue?.rawValue }
    }

    var isInBaseline: Bool { baselineStart != nil }
}

/// Задача без привязки ко времени.
@Model
final class TaskItem {
    var uuid: UUID = UUID()
    var title: String = ""
    var estimateMinutes: Int = 0
    var isDone: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date.distantPast
    var addedAfterLock: Bool = false

    var day: Day?
    var category: ActivityCategory?

    init(title: String, sortOrder: Int, createdAt: Date = .now) {
        self.uuid = UUID()
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

/// Запись о том, что было на самом деле.
@Model
final class FactEntry {
    var uuid: UUID = UUID()
    var title: String = ""
    var start: Date = Date.distantPast
    var end: Date = Date.distantPast
    var note: String = ""
    /// Причина отклонения. Обязательна для дел вне плана.
    var reasonRaw: String?

    var day: Day?
    var category: ActivityCategory?
    /// Блок плана, который выполнялся. `nil` — дело вне плана.
    var block: PlannedBlock?

    init(title: String, start: Date, end: Date, note: String = "") {
        self.uuid = UUID()
        self.title = title
        self.start = start
        self.end = end
        self.note = note
    }

    var reason: DeviationReason? {
        get { reasonRaw.flatMap(DeviationReason.init(rawValue:)) }
        set { reasonRaw = newValue?.rawValue }
    }

    var isUnplanned: Bool { block == nil }
}

/// Запись журнала: правка плана после фиксации.
@Model
final class PlanChange {
    var uuid: UUID = UUID()
    var at: Date = Date.distantPast
    var kindRaw: String = PlanChangeKind.edited.rawValue
    /// Готовое описание правки для показа и отчёта.
    var text: String = ""
    var blockUUID: UUID?

    var day: Day?

    init(kind: PlanChangeKind, text: String, blockUUID: UUID?, at: Date = .now) {
        self.uuid = UUID()
        self.at = at
        self.kindRaw = kind.rawValue
        self.text = text
        self.blockUUID = blockUUID
    }

    var kind: PlanChangeKind { PlanChangeKind(rawValue: kindRaw) ?? .edited }
}

enum PlanChangeKind: String {
    case added
    case removed
    case edited
}
