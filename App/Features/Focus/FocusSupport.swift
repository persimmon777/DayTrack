import DayTrackCore
import SwiftData
import SwiftUI

extension Focus {
    /// Действует ли фокус в этот день (отложенные не предлагаются).
    func isAvailable(on dayKey: Int) -> Bool {
        status != .dropped && range.contains(dayKey)
    }
}

/// Прогресс фокуса: часы факта и сделанные дела.
struct FocusProgress {
    var minutes = 0
    var doneItems = 0
    var totalItems = 0

    /// Считает прогресс всех фокусов по дням периода. Минуты недельного фокуса
    /// засчитываются и его месячному фокусу.
    static func compute(focuses: [Focus], days: [Day]) -> [UUID: FocusProgress] {
        var parentOf: [UUID: UUID] = [:]
        for focus in focuses {
            if let parent = focus.parentUUID { parentOf[focus.uuid] = parent }
        }
        var result: [UUID: FocusProgress] = [:]
        func add(_ id: UUID, minutes: Int = 0, done: Int = 0, total: Int = 0) {
            for target in [id, parentOf[id]].compactMap({ $0 }) {
                var progress = result[target] ?? FocusProgress()
                progress.minutes += minutes
                progress.doneItems += done
                progress.totalItems += total
                result[target] = progress
            }
        }
        let summaryNow = Date.now
        for day in days {
            let comparison = DaySummary(day: day, now: summaryNow).current
            for fact in day.facts {
                guard let focus = fact.effectiveFocusUUID else { continue }
                add(focus, minutes: PlanComparison.minutes(from: fact.start, to: fact.end))
            }
            for block in day.activeBlocks {
                guard let focus = block.focusUUID else { continue }
                let done = comparison.result(for: block.uuid)?.status == .done
                add(focus, done: done ? 1 : 0, total: 1)
            }
            for task in day.tasks {
                guard let focus = task.focusUUID else { continue }
                add(focus, done: task.isDone ? 1 : 0, total: 1)
            }
        }
        return result
    }

    var text: String {
        var parts: [String] = []
        parts.append(minutes > 0 ? DurationText.short(minutes: minutes) : "пока 0 ч")
        if totalItems > 0 { parts.append("дел: \(doneItems) из \(totalItems)") }
        return parts.joined(separator: " · ")
    }
}

/// Выбор фокуса в формах: только фокусы, действующие в этот день.
struct FocusPicker: View {
    let dayKey: Int
    @Binding var selection: UUID?
    var noneTitle = "Без фокуса"

    @Query(sort: \Focus.sortOrder) private var focuses: [Focus]

    private var options: [Focus] {
        focuses
            .filter { $0.isAvailable(on: dayKey) || $0.uuid == selection }
            .sorted { ($0.period == .week ? 0 : 1, $0.sortOrder) < ($1.period == .week ? 0 : 1, $1.sortOrder) }
    }

    var body: some View {
        if !options.isEmpty {
            Picker("Фокус", selection: $selection) {
                Text(noneTitle).tag(UUID?.none)
                ForEach(options) { focus in
                    Text("\(focus.period == .week ? "Неделя" : "Месяц"): \(focus.title)")
                        .tag(UUID?.some(focus.uuid))
                }
            }
        }
    }
}

/// Фокусы недели и месяца строкой над планом.
struct FocusStrip: View {
    let dayKey: Int

    @Query(sort: \Focus.sortOrder) private var focuses: [Focus]

    private var current: [Focus] {
        focuses
            .filter { $0.isAvailable(on: dayKey) && $0.status == .active }
            .sorted { ($0.period == .week ? 0 : 1, $0.sortOrder) < ($1.period == .week ? 0 : 1, $1.sortOrder) }
    }

    var body: some View {
        if !current.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .foregroundStyle(.tint)
                    ForEach(current) { focus in
                        Text(focus.title)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color.accentColor.opacity(focus.period == .week ? 0.18 : 0.08),
                                in: Capsule()
                            )
                    }
                }
            }
        }
    }
}
