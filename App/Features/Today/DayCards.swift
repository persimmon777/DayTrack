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

// MARK: - Итоги дня

/// Состояние плана и итоги сравнения с фактом.
struct DayHeaderCard: View {
    let day: Day?
    let summary: DaySummary
    let canUnlock: Bool
    let onLock: () -> Void
    let onUnlock: () -> Void
    let onAddBlock: () -> Void
    let onAddUnplanned: () -> Void

    private var hasBlocks: Bool { !(day?.activeBlocks.isEmpty ?? true) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let day, let lockedAt = day.lockedAt {
                lockedState(lockedAt: lockedAt)
            } else if hasBlocks {
                draftState
            } else {
                Text("Плана на этот день пока нет. Нажми на колонку «План» на шкале или на кнопку ниже.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button(action: onAddBlock) {
                    Label("Блок плана", systemImage: "plus")
                }
                Button(action: onAddUnplanned) {
                    Label("Дело вне плана", systemImage: "plus")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .card()
    }

    private var draftState: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("План — черновик", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("План готов", action: onLock)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            Text("Запланировано \(DurationText.short(minutes: summary.current.plannedMinutes)). После фиксации правки останутся возможны, но будут видны в отчёте.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func lockedState(lockedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
            } else {
                Text("В плане нет блоков со временем.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
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

                    Text(task.title)
                        .font(.subheadline)
                        .strikethrough(task.isDone)
                        .foregroundStyle(task.isDone ? .secondary : .primary)

                    Spacer(minLength: 0)

                    Menu {
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
