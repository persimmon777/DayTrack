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
    /// Ключевые слова через запятую: по ним категория подбирается по названию дела.
    var keywordsRaw: String = ""

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
    /// Расписание уже подставлено в этот день (повторно само не подставляется).
    var scheduleApplied: Bool = false

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
    /// Откуда взялся блок: вручную, из расписания или из шаблона.
    var sourceRaw: String = Source.manual.rawValue
    /// Фокус недели или месяца, к которому относится блок.
    var focusUUID: UUID?

    enum Source: String {
        case manual
        case schedule
        case template
    }

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
    var focusUUID: UUID?

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
    /// Причина отклонения. Для дел вне плана по умолчанию «Другое».
    var reasonRaw: String?
    /// Фокус записи. Если не задан, берётся фокус блока плана.
    var focusUUID: UUID?

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

    /// Фокус с учётом блока плана.
    var effectiveFocusUUID: UUID? { focusUUID ?? block?.focusUUID }
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

/// Напоминание или событие на день: день рождения, приём у врача, дедлайн.
/// Может быть на весь день или на время и повторяться.
@Model
final class Reminder {
    var uuid: UUID = UUID()
    var title: String = ""
    var note: String = ""
    /// Первый (или единственный) день, ключ вида 20261120.
    var firstDayKey: Int = 0
    /// Время в минутах от полуночи. `nil` — на весь день.
    var minuteOfDay: Int?
    var repeatRaw: String = RepeatRule.none.rawValue
    /// Присылать уведомление.
    var notify: Bool = true
    /// За сколько дней предупредить (0 — в тот же день).
    var leadDays: Int = 0
    var createdAt: Date = Date.distantPast

    init(title: String, firstDayKey: Int) {
        self.uuid = UUID()
        self.title = title
        self.firstDayKey = firstDayKey
        self.createdAt = .now
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRaw) ?? .none }
        set { repeatRaw = newValue.rawValue }
    }

    func occurs(onDayKey key: Int, calendar: Calendar = .current) -> Bool {
        Recurrence.occurs(on: key, first: firstDayKey, rule: repeatRule, calendar: calendar)
    }

    /// «15:00» или «весь день».
    var timeText: String {
        guard let minuteOfDay else { return "весь день" }
        return String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}

/// Правило расписания: каждое такое занятие подставляется в план нужного дня недели.
@Model
final class ScheduleRule {
    var uuid: UUID = UUID()
    var title: String = ""
    var categoryUUID: UUID?
    /// День недели по `Calendar`: 1 — воскресенье, 2 — понедельник, … 7 — суббота.
    var weekday: Int = 2
    var startMinute: Int = 9 * 60
    /// Конец в минутах от полуночи. Меньше начала — значит, после полуночи.
    var endMinute: Int = 10 * 60 + 30
    var parityRaw: String = WeekParity.every.rawValue
    var validFromKey: Int?
    var validUntilKey: Int?
    var isEnabled: Bool = true

    init(title: String, weekday: Int) {
        self.uuid = UUID()
        self.title = title
        self.weekday = weekday
    }

    var parity: WeekParity {
        get { WeekParity(rawValue: parityRaw) ?? .every }
        set { parityRaw = newValue.rawValue }
    }

    var data: ScheduleRuleData {
        ScheduleRuleData(
            weekday: weekday, parity: parity,
            validFromKey: validFromKey, validUntilKey: validUntilKey, isEnabled: isEnabled
        )
    }
}

/// Шаблон дня: набор блоков без привязки к дате.
@Model
final class DayTemplate {
    var uuid: UUID = UUID()
    var name: String = ""
    /// Блоки шаблона в JSON (см. `TemplateItem`).
    var itemsJSON: String = "[]"
    var createdAt: Date = Date.distantPast

    init(name: String, items: [TemplateItem]) {
        self.uuid = UUID()
        self.name = name
        self.createdAt = .now
        self.items = items
    }

    var items: [TemplateItem] {
        get { (try? JSONDecoder().decode([TemplateItem].self, from: Data(itemsJSON.utf8))) ?? [] }
        set { itemsJSON = (try? String(decoding: JSONEncoder().encode(newValue), as: UTF8.self)) ?? "[]" }
    }
}

/// Блок шаблона: название, категория и время в минутах от полуночи.
struct TemplateItem: Codable, Hashable {
    var title: String
    var categoryUUID: UUID?
    var startMinute: Int
    /// Длительность в минутах.
    var durationMinutes: Int
}

/// Фокус недели или месяца: главное, на что идёт время в этот период.
@Model
final class Focus {
    var uuid: UUID = UUID()
    var title: String = ""
    /// Зачем это нужно: связь с большой целью.
    var why: String = ""
    var periodRaw: String = FocusPeriod.week.rawValue
    /// Первый день периода: понедельник недели или 1-е число месяца.
    var periodStartKey: Int = 0
    /// Фокус месяца, шагом к которому служит этот фокус недели.
    var parentUUID: UUID?
    var statusRaw: String = FocusStatus.active.rawValue
    /// Итог периода своими словами.
    var result: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date.distantPast

    init(title: String, period: FocusPeriod, periodStartKey: Int) {
        self.uuid = UUID()
        self.title = title
        self.periodRaw = period.rawValue
        self.periodStartKey = periodStartKey
        self.createdAt = .now
    }

    var period: FocusPeriod {
        get { FocusPeriod(rawValue: periodRaw) ?? .week }
        set { periodRaw = newValue.rawValue }
    }

    var status: FocusStatus {
        get { FocusStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    /// Дни периода фокуса.
    var range: ClosedRange<Int> {
        Periods.range(period == .week ? .week : .month, containing: periodStartKey, calendar: .current)
    }
}

enum FocusPeriod: String, CaseIterable {
    case week
    case month

    var title: String { self == .week ? "Неделя" : "Месяц" }
}

enum FocusStatus: String, CaseIterable {
    case active
    case done
    case dropped

    var title: String {
        switch self {
        case .active: return "В работе"
        case .done: return "Получилось"
        case .dropped: return "Отложено"
        }
    }
}

/// Отметка энергии и настроения (1–5).
@Model
final class EnergyMark {
    var uuid: UUID = UUID()
    var at: Date = Date.distantPast
    var dayKey: Int = 0
    var energy: Int = 3
    var mood: Int = 3

    init(at: Date, dayKey: Int, energy: Int, mood: Int) {
        self.uuid = UUID()
        self.at = at
        self.dayKey = dayKey
        self.energy = energy
        self.mood = mood
    }
}

/// Вечерний разбор дня.
@Model
final class Reflection {
    @Attribute(.unique) var dayKey: Int = 0
    var wentWell: String = ""
    var hindered: String = ""
    var changeTomorrow: String = ""
    /// Оценка дня 1–5, 0 — не поставлена.
    var rating: Int = 0
    var updatedAt: Date = Date.distantPast

    init(dayKey: Int) {
        self.dayKey = dayKey
        self.updatedAt = .now
    }

    var isEmpty: Bool {
        wentWell.isEmpty && hindered.isEmpty && changeTomorrow.isEmpty && rating == 0
    }
}
