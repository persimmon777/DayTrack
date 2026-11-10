import DayTrackCore
import SwiftData
import SwiftUI

/// Карточка блока плана: что запланировано, что внесено в факт и действия.
struct BlockDetailSheet: View {
    let block: PlannedBlock
    let result: BlockResult?
    let onAddFact: () -> Void
    let onEdit: () -> Void
    let onEditFact: (FactEntry) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var isConfirmingDelete = false

    private var facts: [FactEntry] {
        block.facts.sorted { $0.start < $1.start }
    }

    private var missReason: Binding<DeviationReason?> {
        Binding(
            get: { block.missReason },
            set: { DayStore(context: context).markMissed(block, reason: $0) }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        CategoryBadge(
                            colorHex: block.category?.colorHex ?? "7F8C8D",
                            symbol: block.category?.symbol ?? "circle.fill",
                            size: 36
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.title)
                                .font(.headline)
                            Text("\(Format.timeRange(block.start, block.end)) · \(DurationText.short(minutes: PlanComparison.minutes(from: block.start, to: block.end)))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !block.note.isEmpty {
                        Text(block.note)
                            .font(.subheadline)
                    }
                    if let result {
                        statusRow(result)
                    }
                }

                Section("Факт") {
                    ForEach(facts) { fact in
                        Button {
                            onEditFact(fact)
                        } label: {
                            HStack {
                                Text(Format.timeRange(fact.start, fact.end))
                                    .monospacedDigit()
                                Spacer()
                                Text(DurationText.short(minutes: PlanComparison.minutes(from: fact.start, to: fact.end)))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    Button(action: onAddFact) {
                        Label(facts.isEmpty ? "Внести факт" : "Внести ещё одну запись", systemImage: "plus")
                    }
                }

                if facts.isEmpty {
                    Section {
                        Picker("Не сделал", selection: missReason) {
                            Text("Не отмечено").tag(DeviationReason?.none)
                            ForEach(DeviationReason.allCases, id: \.self) { reason in
                                Text(reason.title).tag(DeviationReason?.some(reason))
                            }
                        }
                    } footer: {
                        Text("Если блок не получился, выбери причину. Это не упрёк, а данные: по ним видно, что мешает чаще всего.")
                    }
                }

                Section {
                    Button(action: onEdit) {
                        Label("Изменить блок", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Удалить блок", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Блок плана")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .confirmationDialog("Удалить блок?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive, action: onDelete)
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func statusRow(_ result: BlockResult) -> some View {
        switch result.status {
        case .done:
            Label(doneText(result), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .partial:
            Label(
                "Частично: \(DurationText.short(minutes: result.factMinutes)) из \(DurationText.short(minutes: result.plannedMinutes))",
                systemImage: "circle.lefthalf.filled"
            )
            .foregroundStyle(.orange)
        case .missed:
            Label("Не выполнено", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .pending:
            Label("Ещё впереди", systemImage: "clock")
                .foregroundStyle(.secondary)
        }

        if result.isShifted, let shift = result.startShiftMinutes {
            Label(
                shift > 0
                    ? "Начато позже на \(DurationText.short(minutes: shift))"
                    : "Начато раньше на \(DurationText.short(minutes: -shift))",
                systemImage: "arrow.left.arrow.right"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func doneText(_ result: BlockResult) -> String {
        let extra = result.factMinutes - result.plannedMinutes
        if extra > PlanComparison.shiftThresholdMinutes {
            return "Выполнено, заняло на \(DurationText.short(minutes: extra)) больше"
        }
        return "Выполнено"
    }
}
