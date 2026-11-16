import DayTrackCore
import SwiftData
import SwiftUI

/// Форма блока плана: новый блок или правка существующего.
struct BlockEditorSheet: View {
    enum Mode {
        case new(start: Date)
        case edit(PlannedBlock)
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
    @State private var note: String
    /// День блока. Новый блок можно сразу поставить на любой день.
    @State private var dayDate: Date
    @State private var isConfirmingDelete = false
    /// Пока категорию не выбрали вручную, она подбирается по ключевым словам названия.
    @State private var categoryChosenByUser: Bool
    @FocusState private var isTitleFocused: Bool

    private let clock = DayClock.app
    private let isLockedDay: Bool

    init(
        dayKey: Int, mode: Mode, categories: [ActivityCategory],
        onFinish: @escaping (EditorAction) -> Void
    ) {
        self.dayKey = dayKey
        self.mode = mode
        self.categories = categories
        self.onFinish = onFinish
        _dayDate = State(initialValue: DayClock.app.calendarDate(forKey: dayKey) ?? .now)

        switch mode {
        case .new(let start):
            _title = State(initialValue: "")
            _categoryID = State(initialValue: nil)
            _start = State(initialValue: start)
            _end = State(initialValue: start.addingTimeInterval(3600))
            _note = State(initialValue: "")
            _categoryChosenByUser = State(initialValue: false)
            isLockedDay = false
        case .edit(let block):
            _title = State(initialValue: block.title)
            _categoryID = State(initialValue: block.category?.uuid)
            _start = State(initialValue: block.start)
            _end = State(initialValue: block.end)
            _note = State(initialValue: block.note)
            _categoryChosenByUser = State(initialValue: block.category != nil)
            isLockedDay = block.day?.isLocked ?? false
        }
    }

    private var isNew: Bool {
        if case .new = mode { return true }
        return false
    }

    private var category: ActivityCategory? {
        categories.first { $0.uuid == categoryID }
    }

    /// День, в который попадёт блок.
    private var targetDayKey: Int {
        isNew ? clock.key(for: dayDate) : dayKey
    }

    /// Время из полей формы, приведённое к выбранному дню.
    private var resolvedStart: Date {
        clock.resolve(timeOf: start, inDay: targetDayKey) ?? start
    }

    private var resolvedEnd: Date {
        clock.end(after: resolvedStart, timeOf: end)
    }

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (category?.name ?? "") : trimmed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $title)
                        .focused($isTitleFocused)
                    CategoryPicker(categories: categories, selection: Binding(
                        get: { categoryID },
                        set: { categoryID = $0; categoryChosenByUser = true }
                    ))
                } footer: {
                    if title.isEmpty {
                        Text("Название можно не писать: подставится название категории.")
                    } else if !categoryChosenByUser, category != nil {
                        Text("Категория подобрана по ключевым словам.")
                    }
                }

                Section {
                    if isNew {
                        DatePicker("День", selection: $dayDate, displayedComponents: .date)
                    }
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
                } footer: {
                    if let window = clock.window(forKey: targetDayKey), resolvedEnd > window.end {
                        Text("Блок заканчивается уже на следующий день.")
                    } else if targetDayKey != dayKey {
                        Text("Блок попадёт в план другого дня. Так можно планировать заранее: например, приём у врача через неделю.")
                    }
                }

                Section("Заметка") {
                    TextField("Необязательно", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if isLockedDay {
                    Section {
                        Text("План этого дня уже зафиксирован. Правка сохранится и будет отмечена в журнале правок.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !isNew {
                    Section {
                        Button("Удалить блок", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Новый блок" : "Блок плана")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(resolvedTitle.isEmpty)
                }
            }
            .confirmationDialog("Удалить блок?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    onFinish(.delete)
                }
            }
            .onAppear {
                if isNew { isTitleFocused = true }
            }
            .onChange(of: title) { _, newTitle in
                guard !categoryChosenByUser else { return }
                if let match = CategoryKeywords.match(title: newTitle, in: categories) {
                    categoryID = match.uuid
                }
            }
        }
    }

    private func save() {
        let store = DayStore(context: context)
        switch mode {
        case .new:
            store.addBlock(
                dayKey: targetDayKey, title: resolvedTitle, category: category,
                start: resolvedStart, end: resolvedEnd, note: note
            )
        case .edit(let block):
            store.updateBlock(
                block, title: resolvedTitle, category: category,
                start: resolvedStart, end: resolvedEnd, note: note
            )
        }
        onFinish(.save)
        dismiss()
    }
}
