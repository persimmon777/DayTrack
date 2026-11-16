import DayTrackCore
import SwiftData
import SwiftUI

/// Вкладка «Факт»: что было на самом деле, списком по времени.
struct FactView: View {
    let dayKey: Int

    @Environment(\.modelContext) private var context
    @Query private var days: [Day]
    @Query private var previousDays: [Day]
    @Query private var energyMarks: [EnergyMark]
    @Query private var reflections: [Reflection]

    @State private var sheet: DaySheet?

    private let clock = DayClock.app

    init(dayKey: Int) {
        self.dayKey = dayKey
        let previousKey = DayClock.app.key(byAdding: -1, to: dayKey)
        _days = Query(filter: #Predicate<Day> { $0.key == dayKey })
        _previousDays = Query(filter: #Predicate<Day> { $0.key == previousKey })
        _energyMarks = Query(filter: #Predicate<EnergyMark> { $0.dayKey == dayKey }, sort: \EnergyMark.at)
        _reflections = Query(filter: #Predicate<Reflection> { $0.dayKey == dayKey })
    }

    private var day: Day? { days.first }
    private var window: DateInterval? { clock.window(forKey: dayKey) }
    private var isToday: Bool { clock.key(for: .now) == dayKey }

    private var ownFacts: [FactEntry] {
        (day?.facts ?? []).sorted { $0.start < $1.start }
    }

    /// Записи прошлого дня, которые заходят в этот день (например, сон после полуночи).
    private var carriedFacts: [FactEntry] {
        guard let window else { return [] }
        return (previousDays.first?.facts ?? [])
            .filter { $0.end > window.start }
            .sorted { $0.start < $1.start }
    }

    private enum Row: Identifiable {
        case carried(FactEntry)
        case fact(FactEntry)
        case gap(start: Date, end: Date)

        var id: String {
            switch self {
            case .carried(let fact): return "c-\(fact.uuid)"
            case .fact(let fact): return "f-\(fact.uuid)"
            case .gap(let start, _): return "g-\(start.timeIntervalSinceReferenceDate)"
            }
        }
    }

    /// Записи по порядку, с пропусками между ними.
    private var rows: [Row] {
        guard let window, !ownFacts.isEmpty else { return carriedFacts.map { .carried($0) } }
        var result: [Row] = carriedFacts.map { .carried($0) }
        var cursor = max(carriedFacts.map(\.end).max() ?? window.start, window.start)
        for fact in ownFacts {
            if fact.start.timeIntervalSince(cursor) >= 60 {
                result.append(.gap(start: cursor, end: fact.start))
            }
            result.append(.fact(fact))
            cursor = max(cursor, fact.end)
        }
        return result
    }

    var body: some View {
        List {
            if RestTimer.isRunning || isToday {
                RestBanner()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if !ownFacts.isEmpty {
                Section {
                    summary
                }
            }

            Section {
                if ownFacts.isEmpty && carriedFacts.isEmpty {
                    Text("Записей пока нет. Нажми «+», чтобы отметить, что ты делал.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(rows) { row in
                    rowView(row)
                }
            }

            if !energyMarks.isEmpty {
                Section("Энергия и настроение") {
                    ForEach(energyMarks) { mark in
                        HStack {
                            Text(Format.time(mark.at))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Spacer()
                            Label("\(mark.energy)", systemImage: "bolt.fill")
                            Label("\(mark.mood)", systemImage: "face.smiling")
                                .padding(.leading, 8)
                        }
                        .font(.subheadline)
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(mark)
                                try? context.save()
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    sheet = DaySheet(kind: .reflection)
                } label: {
                    Label(
                        (reflections.first?.isEmpty ?? true) ? "Вечерний разбор" : "Вечерний разбор заполнен",
                        systemImage: (reflections.first?.isEmpty ?? true) ? "moon.stars" : "checkmark.seal"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 72)
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingAddMenu(label: "Добавить") {
                Button(action: addNext) {
                    Label("Запись факта", systemImage: "plus.circle")
                }
                Button {
                    sheet = DaySheet(kind: .restStart)
                } label: {
                    Label("Начать отдых", systemImage: "cup.and.saucer")
                }
                Button {
                    sheet = DaySheet(kind: .energy)
                } label: {
                    Label("Энергия и настроение", systemImage: "bolt.heart")
                }
                Button {
                    sheet = DaySheet(kind: .reflection)
                } label: {
                    Label("Вечерний разбор", systemImage: "moon.stars")
                }
            }
        }
        .sheet(item: $sheet) { item in
            DaySheetView(sheet: item, dayKey: dayKey) { sheet = $0 }
        }
    }

    // MARK: Строки

    private var summary: some View {
        let total = ownFacts.reduce(0) { $0 + PlanComparison.minutes(from: $1.start, to: $1.end) }
        let unplanned = ownFacts.filter(\.isUnplanned)
            .reduce(0) { $0 + PlanComparison.minutes(from: $1.start, to: $1.end) }
        return VStack(alignment: .leading, spacing: 2) {
            Text("Отмечено \(DurationText.short(minutes: total))")
                .font(.headline)
            if unplanned > 0 {
                Text("Из них вне плана \(DurationText.short(minutes: unplanned))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row {
        case .carried(let fact):
            factRow(fact)
                .opacity(0.5)
        case .fact(let fact):
            Button {
                sheet = DaySheet(kind: .editFact(fact))
            } label: {
                factRow(fact)
            }
            .foregroundStyle(.primary)
            .swipeActions {
                Button(role: .destructive) {
                    DayStore(context: context).deleteFact(fact)
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
        case .gap(let start, let end):
            Button {
                sheet = DaySheet(kind: .newFact(block: nil, start: start, end: end))
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.title3)
                        .frame(width: 28)
                    Text("Не отмечено")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Format.timeRange(start, end))
                            .font(.subheadline)
                            .monospacedDigit()
                        Text(DurationText.short(minutes: PlanComparison.minutes(from: start, to: end)))
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func factRow(_ fact: FactEntry) -> some View {
        HStack(spacing: 12) {
            CategoryBadge(
                colorHex: fact.category?.colorHex ?? "7F8C8D",
                symbol: fact.category?.symbol ?? "circle.fill"
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(fact.title)
                Text(detail(fact))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.timeRange(fact.start, fact.end))
                    .font(.subheadline)
                    .monospacedDigit()
                Text(DurationText.short(minutes: PlanComparison.minutes(from: fact.start, to: fact.end)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func detail(_ fact: FactEntry) -> String {
        if let block = fact.block {
            return "по плану: \(block.title)"
        }
        return "вне плана · \((fact.reason ?? .other).title)"
    }

    // MARK: Новая запись

    /// Новая запись начинается там, где закончилась последняя, а если записей
    /// ещё нет — в начале дня (00:00) или после записи, перешедшей с прошлого дня.
    /// Сегодня конец по умолчанию — текущее время.
    private func addNext() {
        guard let window else { return }
        let lastEnd = (ownFacts.map(\.end) + carriedFacts.map(\.end)).max() ?? window.start
        let start = min(max(lastEnd, window.start), window.end.addingTimeInterval(-300))

        let now = Date.now
        let roundedNow = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 300).rounded(.down) * 300)
        let end: Date
        if isToday, roundedNow.timeIntervalSince(start) >= 300 {
            end = roundedNow
        } else {
            end = start.addingTimeInterval(3600)
        }
        sheet = DaySheet(kind: .newFact(block: nil, start: start, end: end))
    }
}
