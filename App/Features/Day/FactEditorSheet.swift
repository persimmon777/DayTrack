import DayTrackCore
import SwiftData
import SwiftUI

/// Форма записи факта. Обязательно только время: блок плана подбирается сам
/// по времени, название берётся из блока или категории, причина по умолчанию «Другое».
struct FactEditorSheet: View {
    enum Mode {
        /// Новая запись. Если `start` не задан, а `block` задан, время берётся из блока.
        case new(block: PlannedBlock?, start: Date?, end: Date?)
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
    @State private var blockID: UUID?
    @State private var reason: DeviationReason?
    @State private var note: String
    @State private var focusID: UUID?
    @State private var isConfirmingDelete = false
    /// Пока пользователь сам не выбрал блок или категорию, они подбираются по времени.
    @State private var blockChosenByUser: Bool
    @State private var categoryChosenByUser: Bool

    private let clock = DayClock.app
    /// Блоки плана, к которым можно привязать запись.
    private let blocks: [PlannedBlock]

    init(
        dayKey: Int, mode: Mode, categories: [ActivityCategory], blocks: [PlannedBlock],
        onFinish: @escaping (EditorAction) -> Void
    ) {
        self.dayKey = dayKey
        self.mode = mode
        self.categories = categories
        self.onFinish = onFinish

        var options = blocks
        switch mode {
        case .new(let block, let givenStart, let givenEnd):
            if let block, !options.contains(where: { $0.uuid == block.uuid }) { options.append(block) }
            let clock = DayClock.app
            let fallback = clock.window(forKey: dayKey)?.start ?? .now
            let start = givenStart ?? block?.start ?? fallback
            let end = givenEnd ?? block?.end ?? start.addingTimeInterval(3600)
            let picked = block ?? Self.suggestedBlock(in: options, start: start, end: end)
            _title = State(initialValue: "")
            _categoryID = State(initialValue: picked?.category?.uuid)
            _start = State(initialValue: start)
            _end = State(initialValue: end)
            _blockID = State(initialValue: picked?.uuid)
            _reason = State(initialValue: nil)
            _note = State(initialValue: "")
            _focusID = State(initialValue: nil)
            _blockChosenByUser = State(initialValue: block != nil)
            _categoryChosenByUser = State(initialValue: false)
        case .edit(let fact):
            if let block = fact.block, !options.contains(where: { $0.uuid == block.uuid }) { options.append(block) }
            _title = State(initialValue: fact.title)
            _categoryID = State(initialValue: fact.category?.uuid)
            _start = State(initialValue: fact.start)
            _end = State(initialValue: fact.end)
            _blockID = State(initialValue: fact.block?.uuid)
            _reason = State(initialValue: fact.reason)
            _note = State(initialValue: fact.note)
            _focusID = State(initialValue: fact.focusUUID)
            _blockChosenByUser = State(initialValue: true)
            _categoryChosenByUser = State(initialValue: true)
        }
        self.blocks = options.sorted { $0.start < $1.start }
    }

    /// Блок плана, больше всего пересекающийся с записью по времени.
    private static func suggestedBlock(in blocks: [PlannedBlock], start: Date, end: Date) -> PlannedBlock? {
        var best: (block: PlannedBlock, overlap: TimeInterval)?
        for block in blocks {
            let overlap = min(end, block.end).timeIntervalSince(max(start, block.start))
            guard overlap > 0 else { continue }
            if overlap > (best?.overlap ?? 0) { best = (block, overlap) }
        }
        return best?.block
    }

    private var isNew: Bool {
        if case .new = mode { return true }
        return false
    }

    private var block: PlannedBlock? { blocks.first { $0.uuid == blockID } }
    private var category: ActivityCategory? { categories.first { $0.uuid == categoryID } }
    private var isUnplanned: Bool { blockID == nil }

    private var resolvedStart: Date {
        clock.resolve(timeOf: start, inDay: dayKey) ?? start
    }

    private var resolvedEnd: Date {
        clock.end(after: resolvedStart, timeOf: end)
    }

    /// Название, которое подставится, если поле оставить пустым.
    private var fallbackTitle: String {
        block?.title ?? category?.name ?? ""
    }

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackTitle : trimmed
    }

    private var blockSelection: Binding<UUID?> {
        Binding(
            get: { blockID },
            set: { newValue in
                blockID = newValue
                blockChosenByUser = true
                suggestCategory()
            }
        )
    }

    private var categorySelection: Binding<UUID?> {
        Binding(
            get: { categoryID },
            set: { newValue in
                categoryID = newValue
                categoryChosenByUser = true
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
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
                }

                Section {
                    TextField(fallbackTitle.isEmpty ? "Что делал" : fallbackTitle, text: $title)
                    CategoryPicker(categories: categories, selection: categorySelection)
                    if !blocks.isEmpty {
                        Picker("По плану", selection: blockSelection) {
                            Text("Вне плана").tag(UUID?.none)
                            ForEach(blocks) { block in
                                Text("\(Format.time(block.start)) \(block.title)")
                                    .tag(UUID?.some(block.uuid))
                            }
                        }
                    }
                } footer: {
                    if !blocks.isEmpty, !blockChosenByUser {
                        Text("Блок плана подобран по времени. Если делал другое, выбери «Вне плана».")
                    }
                }

                Section {
                    FocusPicker(
                        dayKey: dayKey,
                        selection: $focusID,
                        noneTitle: block?.focusUUID == nil ? "Без фокуса" : "Как у блока плана"
                    )
                }

                Section {
                    Picker("Причина", selection: $reason) {
                        Text("Не указывать").tag(DeviationReason?.none)
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
                        Text("Необязательно. Если причину не выбрать, сохранится «Другое».")
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
            .navigationTitle(isNew ? "Новая запись" : "Запись факта")
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
            .onChange(of: title) { _, _ in suggestCategory() }
            .onChange(of: start) { _, _ in suggestBlock() }
            .onChange(of: end) { _, _ in suggestBlock() }
            .confirmationDialog("Удалить запись?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    onFinish(.delete)
                }
            }
        }
    }

    private func suggestBlock() {
        guard !blockChosenByUser else { return }
        blockID = Self.suggestedBlock(in: blocks, start: resolvedStart, end: resolvedEnd)?.uuid
        suggestCategory()
    }

    /// Категория по ключевым словам названия, иначе категория блока плана.
    private func suggestCategory() {
        guard !categoryChosenByUser else { return }
        let typed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let byKeywords = typed.isEmpty ? nil : CategoryKeywords.match(title: typed, in: categories)
        categoryID = byKeywords?.uuid ?? block?.category?.uuid
    }

    private func save() {
        let store = DayStore(context: context)
        let finalReason = reason ?? (isUnplanned ? .other : nil)
        switch mode {
        case .new:
            let fact = store.addFact(
                dayKey: dayKey, block: block, title: resolvedTitle, category: category,
                start: resolvedStart, end: resolvedEnd, reason: finalReason, note: note
            )
            fact.focusUUID = focusID
            store.save()
        case .edit(let fact):
            fact.focusUUID = focusID
            store.updateFact(
                fact, block: block, title: resolvedTitle, category: category,
                start: resolvedStart, end: resolvedEnd, reason: finalReason, note: note
            )
        }
        onFinish(.save)
        dismiss()
    }
}
