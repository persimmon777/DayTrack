import DayTrackCore
import SwiftData
import SwiftUI

/// Форма записи факта: по блоку плана или вне плана.
struct FactEditorSheet: View {
    enum Mode {
        /// Новая запись. `block` — блок плана, по которому вносится факт;
        /// `start` — время, на которое нажали на шкале.
        case new(block: PlannedBlock?, start: Date?)
        case edit(FactEntry)
    }

    let dayKey: Int
    let mode: Mode
    let categories: [ActivityCategory]
    let onFinish: (EditorAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var categoryID: UUID?
    @State private var start: Date
    @State private var end: Date
    @State private var reason: DeviationReason?
    @State private var note: String
    @State private var isConfirmingDelete = false

    private let clock = DayClock.app
    /// Блок плана, к которому относится запись.
    private let block: PlannedBlock?
    /// Описание блока, снятое при открытии формы.
    private let planLine: String?

    init(
        dayKey: Int, mode: Mode, categories: [ActivityCategory],
        onFinish: @escaping (EditorAction) -> Void
    ) {
        self.dayKey = dayKey
        self.mode = mode
        self.categories = categories
        self.onFinish = onFinish

        let linkedBlock: PlannedBlock?
        switch mode {
        case .new(let block, let tappedStart):
            linkedBlock = block
            if let block {
                // Время подставляется из плана: обычно остаётся поправить начало и конец.
                _title = State(initialValue: block.title)
                _categoryID = State(initialValue: block.category?.uuid)
                _start = State(initialValue: block.start)
                _end = State(initialValue: block.end)
            } else {
                let clock = DayClock.app
                let fallback = clock.key(for: .now) == dayKey
                    ? Date.now.addingTimeInterval(-3600)
                    : clock.resolve(hour: 12, minute: 0, inDay: dayKey) ?? .now
                let start = tappedStart ?? fallback
                _title = State(initialValue: "")
                _categoryID = State(initialValue: nil)
                _start = State(initialValue: start)
                _end = State(initialValue: start.addingTimeInterval(3600))
            }
            _reason = State(initialValue: nil)
            _note = State(initialValue: "")
        case .edit(let fact):
            linkedBlock = fact.block
            _title = State(initialValue: fact.title)
            _categoryID = State(initialValue: fact.category?.uuid)
            _start = State(initialValue: fact.start)
            _end = State(initialValue: fact.end)
            _reason = State(initialValue: fact.reason)
            _note = State(initialValue: fact.note)
        }
        block = linkedBlock
        planLine = linkedBlock.map { "«\($0.title)», \(Format.timeRange($0.start, $0.end))" }
    }

    private var isNew: Bool {
        if case .new = mode { return true }
        return false
    }

    private var isUnplanned: Bool { block == nil }

    private var category: ActivityCategory? {
        categories.first { $0.uuid == categoryID }
    }

    private var resolvedStart: Date {
        clock.resolve(timeOf: start, inDay: dayKey) ?? start
    }

    private var resolvedEnd: Date {
        clock.end(after: resolvedStart, timeOf: end)
    }

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (category?.name ?? "") : trimmed
    }

    private var canSave: Bool {
        !resolvedTitle.isEmpty && (!isUnplanned || reason != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let planLine {
                    Section("По плану") {
                        Text(planLine)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField(isUnplanned ? "Что делал" : "Название", text: $title)
                    CategoryPicker(categories: categories, selection: $categoryID)
                }

                Section {
                    DatePicker("Начало", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Конец", selection: $end, displayedComponents: .hourAndMinute)
                    DurationChips { minutes in
                        end = resolvedStart.addingTimeInterval(Double(minutes) * 60)
                    }
                    LabeledContent(
                        "Длительность",
                        value: DurationText.short(
                            minutes: PlanComparison.minutes(from: resolvedStart, to: resolvedEnd)
                        )
                    )
                } header: {
                    Text("Как было на самом деле")
                }

                Section {
                    Picker("Причина", selection: $reason) {
                        Text(isUnplanned ? "Выбери причину" : "Нет").tag(DeviationReason?.none)
                        ForEach(DeviationReason.allCases, id: \.self) { reason in
                            Text(reason.title).tag(DeviationReason?.some(reason))
                        }
                    }
                    TextField("Заметка, необязательно", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text(isUnplanned ? "Почему это появилось" : "Если пошло не по плану")
                } footer: {
                    if isUnplanned {
                        Text("Для дела вне плана причина обязательна: по причинам потом видно, что чаще всего сбивает день.")
                    }
                }

                if !isNew {
                    Section {
                        Button("Удалить запись", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isUnplanned ? "Дело вне плана" : "Факт по блоку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog("Удалить запись?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    onFinish(.delete)
                }
            }
        }
    }

    private func save() {
        let store = DayStore(context: context)
        switch mode {
        case .new:
            store.addFact(
                dayKey: dayKey, block: block, title: resolvedTitle, category: category,
                start: resolvedStart, end: resolvedEnd, reason: reason, note: note
            )
        case .edit(let fact):
            store.updateFact(
                fact, title: resolvedTitle, category: category,
                start: resolvedStart, end: resolvedEnd, reason: reason, note: note
            )
        }
        onFinish(.save)
        dismiss()
    }
}
