import DayTrackCore
import SwiftData
import SwiftUI

/// Что открыто поверх экрана дня.
struct DaySheet: Identifiable {
    enum Kind {
        case newBlock(start: Date)
        case editBlock(PlannedBlock)
        case blockDetail(PlannedBlock)
        /// Новая запись факта. Если `start` не задан, а `block` задан,
        /// время берётся из блока плана.
        case newFact(block: PlannedBlock?, start: Date?, end: Date?)
        case editFact(FactEntry)
        /// Новое (`nil`) или существующее напоминание.
        case reminder(Reminder?)
        case editTask(TaskItem)
        case energy
        case reflection
        case restStart
    }

    // Отдельный идентификатор, не зависящий от записи: к удалённой записи
    // обращаться нельзя, а окно в этот момент ещё закрывается.
    let id = UUID()
    let kind: Kind
}

/// Чем закончилось редактирование в окне.
enum EditorAction {
    case save
    case delete
}

/// Содержимое окна для любой вкладки дня.
struct DaySheetView: View {
    let sheet: DaySheet
    let dayKey: Int
    /// Открыть другое окно вместо текущего или закрыть (`nil`).
    let present: (DaySheet?) -> Void

    @Environment(\.modelContext) private var context
    @Query private var days: [Day]
    @Query(sort: \ActivityCategory.sortOrder) private var categories: [ActivityCategory]

    init(sheet: DaySheet, dayKey: Int, present: @escaping (DaySheet?) -> Void) {
        self.sheet = sheet
        self.dayKey = dayKey
        self.present = present
        _days = Query(filter: #Predicate<Day> { $0.key == dayKey })
    }

    private var day: Day? { days.first }
    private var blocks: [PlannedBlock] { (day?.activeBlocks ?? []).sorted { $0.start < $1.start } }

    var body: some View {
        switch sheet.kind {
        case .newBlock(let start):
            BlockEditorSheet(dayKey: dayKey, mode: .new(start: start), categories: categories) { _ in }
        case .editBlock(let block):
            BlockEditorSheet(dayKey: dayKey, mode: .edit(block), categories: categories) { action in
                if action == .delete { deleteAfterDismiss { $0.deleteBlock(block) } }
            }
        case .blockDetail(let block):
            BlockDetailSheet(
                block: block,
                result: DaySummary(day: day, now: .now).status(of: block),
                onAddFact: { present(DaySheet(kind: .newFact(block: block, start: nil, end: nil))) },
                onEdit: { present(DaySheet(kind: .editBlock(block))) },
                onEditFact: { present(DaySheet(kind: .editFact($0))) },
                onDelete: { deleteAfterDismiss { $0.deleteBlock(block) } }
            )
        case .newFact(let block, let start, let end):
            FactEditorSheet(
                dayKey: dayKey,
                mode: .new(block: block, start: start, end: end),
                categories: categories,
                blocks: blocks
            ) { _ in }
        case .editFact(let fact):
            FactEditorSheet(dayKey: dayKey, mode: .edit(fact), categories: categories, blocks: blocks) { action in
                if action == .delete { deleteAfterDismiss { $0.deleteFact(fact) } }
            }
        case .reminder(let reminder):
            ReminderEditorSheet(reminder: reminder, dayKey: dayKey)
        case .energy:
            EnergySheet(dayKey: dayKey)
        case .restStart:
            RestStartSheet(dayKey: dayKey)
        case .reflection:
            ReflectionSheet(dayKey: dayKey)
        case .editTask(let task):
            TaskEditorSheet(task: task, categories: categories) {
                deleteAfterDismiss { $0.deleteTask(task) }
            }
        }
    }

    /// Запись удаляется после того, как окно закрылось: пока оно закрывается,
    /// оно ещё показывает эту запись.
    private func deleteAfterDismiss(_ delete: @escaping @MainActor (DayStore) -> Void) {
        let store = DayStore(context: context)
        present(nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            delete(store)
        }
    }
}
