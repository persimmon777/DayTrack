import DayTrackCore
import SwiftUI

/// Общий вид карточки на экране дня.
private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension View {
    func card() -> some View { modifier(CardBackground()) }
}

// MARK: - Состояние плана

/// Черновик или зафиксированный план и кнопки фиксации.
struct PlanStatusCard: View {
    let day: Day?
    let plannedMinutes: Int
    let breakdown: [CategoryMinutes]
    let canUnlock: Bool
    let onLock: () -> Void
    let onUnlock: () -> Void

    private var hasBlocks: Bool { !(day?.activeBlocks.isEmpty ?? true) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lockedAt = day?.lockedAt {
                HStack {
                    Label("План зафиксирован в \(Format.time(lockedAt))", systemImage: "lock.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if canUnlock {
                        Menu {
                            Button("Снять фиксацию", systemImage: "lock.open", action: onUnlock)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                Text("Запланировано \(DurationText.short(minutes: plannedMinutes)). Правки остаются возможны и попадают в журнал.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if hasBlocks {
                HStack {
                    Label("План — черновик", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("План готов", action: onLock)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                Text("Запланировано \(DurationText.short(minutes: plannedMinutes)). После фиксации правки будут видны в отчёте.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Плана на этот день пока нет. Нажми «+» или на шкалу.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !breakdown.isEmpty {
                CategoryBreakdownView(items: breakdown)
            }
        }
        .card()
    }
}

/// Время по категориям.
struct CategoryMinutes {
    var name: String
    var colorHex: String
    var minutes: Int
}

/// Полоса с долями категорий и подписи под ней.
struct CategoryBreakdownView: View {
    let items: [CategoryMinutes]

    private var total: Int { max(items.reduce(0) { $0 + $1.minutes }, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        Rectangle()
                            .fill(Color(hex: item.colorHex))
                            .frame(width: max(2, (geometry.size.width - CGFloat(items.count - 1) * 2)
                                * CGFloat(item.minutes) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: item.colorHex))
                                .frame(width: 8, height: 8)
                            Text("\(item.name) \(DurationText.short(minutes: item.minutes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Итоги сравнения

/// Процент выполнения и итоги сравнения плана с фактом.
struct ComparisonCard: View {
    let day: Day?
    let summary: DaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let completion = summary.current.completion {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(DurationText.percent(completion))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("плана выполнено")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(max(completion, 0), 1))

                Text(detailLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if summary.planWasEdited, let baseline = summary.baseline?.completion {
                    Text("К исходному плану, без правок: \(DurationText.percent(baseline))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if summary.current.unplannedMinutes > 0 {
                Text("Плана на этот день не было. Отмечено \(DurationText.short(minutes: summary.current.unplannedMinutes)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("На этот день нет ни плана, ни факта.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var detailLine: String {
        let current = summary.current
        var parts = [
            "Сделано \(DurationText.short(minutes: current.creditedMinutes)) из \(DurationText.short(minutes: current.plannedMinutes))"
        ]
        if current.unplannedMinutes > 0 {
            parts.append("вне плана \(DurationText.short(minutes: current.unplannedMinutes))")
        }
        let missed = current.count(of: .missed)
        if missed > 0 {
            parts.append("не сделано блоков: \(missed)")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Задачи без времени

struct TasksCard: View {
    let tasks: [TaskItem]
    let onAdd: (String) -> Void
    let onToggle: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void

    @State private var newTitle = ""
    @FocusState private var isAdding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Задачи без времени")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !tasks.isEmpty {
                    Text("\(tasks.filter(\.isDone).count) из \(tasks.count)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(tasks) { task in
                HStack(spacing: 8) {
                    Button {
                        onToggle(task)
                    } label: {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(task.isDone ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onEdit(task)
                    } label: {
                        HStack(spacing: 6) {
                            if let category = task.category {
                                Circle()
                                    .fill(Color(hex: category.colorHex))
                                    .frame(width: 8, height: 8)
                            }
                            Text(task.title)
                                .font(.subheadline)
                                .strikethrough(task.isDone)
                                .foregroundStyle(task.isDone ? .secondary : .primary)
                            if task.estimateMinutes > 0 {
                                Text(DurationText.short(minutes: task.estimateMinutes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button("Изменить", systemImage: "pencil") {
                            onEdit(task)
                        }
                        Button("Удалить", systemImage: "trash", role: .destructive) {
                            onDelete(task)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                TextField("Новая задача", text: $newTitle)
                    .font(.subheadline)
                    .focused($isAdding)
                    .submitLabel(.done)
                    .onSubmit(add)
            }
        }
        .card()
    }

    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        onAdd(title)
        newTitle = ""
        isAdding = true
    }
}

// MARK: - Правки плана

struct PlanChangesCard: View {
    let changes: [PlanChange]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Правки плана после фиксации")
                .font(.subheadline.weight(.semibold))
            ForEach(changes) { change in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Format.time(change.at))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(change.text)
                        .font(.footnote)
                }
            }
        }
        .card()
    }
}
