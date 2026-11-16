import DayTrackCore
import SwiftData
import SwiftUI

/// Вечерний разбор: причины несделанного и короткая рефлексия.
struct ReflectionSheet: View {
    let dayKey: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var days: [Day]
    @Query private var reflections: [Reflection]

    @State private var wentWell = ""
    @State private var hindered = ""
    @State private var changeTomorrow = ""
    @State private var rating = 0
    @State private var loaded = false

    init(dayKey: Int) {
        self.dayKey = dayKey
        _days = Query(filter: #Predicate<Day> { $0.key == dayKey })
        _reflections = Query(filter: #Predicate<Reflection> { $0.dayKey == dayKey })
    }

    private var day: Day? { days.first }

    /// Блоки, время которых прошло, а факта нет.
    private var missedBlocks: [PlannedBlock] {
        guard let day else { return [] }
        let comparison = DaySummary(day: day, now: .now).current
        return day.activeBlocks
            .filter { comparison.result(for: $0.uuid)?.status == .missed }
            .sorted { $0.start < $1.start }
    }

    private var summaryLine: String? {
        guard let day else { return nil }
        let comparison = DaySummary(day: day, now: .now).current
        guard let completion = comparison.completion else { return nil }
        return "Выполнено \(DurationText.percent(completion)) плана: \(DurationText.short(minutes: comparison.creditedMinutes)) из \(DurationText.short(minutes: comparison.plannedMinutes))."
    }

    var body: some View {
        NavigationStack {
            Form {
                if let summaryLine {
                    Section {
                        Text(summaryLine)
                        Text("Любой процент — это данные, а не оценка тебя. Главное — понять, что помогло и что мешало.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !missedBlocks.isEmpty {
                    Section {
                        ForEach(missedBlocks) { block in
                            Picker(selection: Binding(
                                get: { block.missReason },
                                set: { block.missReason = $0; try? context.save() }
                            )) {
                                Text("Не указана").tag(DeviationReason?.none)
                                ForEach(DeviationReason.allCases, id: \.self) { Text($0.title).tag(DeviationReason?.some($0)) }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(block.title)
                                    Text(Format.timeRange(block.start, block.end))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Что не получилось")
                    } footer: {
                        Text("Выбери причину для каждого блока. В аналитике станет видно, что мешает чаще всего.")
                    }
                }

                Section("Что получилось") {
                    TextField("Даже маленькое считается", text: $wentWell, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Что помешало") {
                    TextField("Без самокритики, просто факты", text: $hindered, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Что изменю завтра") {
                    TextField("Одно конкретное действие", text: $changeTomorrow, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Оценка дня") {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { level in
                            Image(systemName: level <= rating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(level <= rating ? Color.yellow : Color.secondary)
                                .onTapGesture { rating = level == rating ? 0 : level }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Вечерний разбор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let reflection = reflections.first else { return }
        wentWell = reflection.wentWell
        hindered = reflection.hindered
        changeTomorrow = reflection.changeTomorrow
        rating = reflection.rating
    }

    private func save() {
        let reflection = reflections.first ?? {
            let new = Reflection(dayKey: dayKey)
            context.insert(new)
            return new
        }()
        reflection.wentWell = wentWell.trimmingCharacters(in: .whitespacesAndNewlines)
        reflection.hindered = hindered.trimmingCharacters(in: .whitespacesAndNewlines)
        reflection.changeTomorrow = changeTomorrow.trimmingCharacters(in: .whitespacesAndNewlines)
        reflection.rating = rating
        reflection.updatedAt = .now
        try? context.save()
        dismiss()
    }
}
