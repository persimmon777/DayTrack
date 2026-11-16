import AppIntents
import SwiftUI
import WidgetKit

enum BalancePeriod: String, AppEnum {
    case today
    case week

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Период"
    static var caseDisplayRepresentations: [BalancePeriod: DisplayRepresentation] = [
        .today: "Сегодня",
        .week: "Неделя",
    ]
}

struct BalanceConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Баланс"
    static var description = IntentDescription("Учёба, отдых и сон по факту против цели.")

    @Parameter(title: "Период", default: .today)
    var period: BalancePeriod
}

struct BalanceEntry: TimelineEntry {
    let date: Date
    let period: BalancePeriod
    let snapshot: WidgetSnapshot?
}

struct BalanceProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: .now, period: .today, snapshot: .preview)
    }

    func snapshot(for configuration: BalanceConfigIntent, in context: Context) async -> BalanceEntry {
        BalanceEntry(
            date: .now,
            period: configuration.period,
            snapshot: context.isPreview ? .preview : WidgetSnapshotStore.read()
        )
    }

    func timeline(for configuration: BalanceConfigIntent, in context: Context) async -> Timeline<BalanceEntry> {
        let entry = BalanceEntry(date: .now, period: configuration.period, snapshot: WidgetSnapshotStore.read())
        // Приложение само обновляет виджет после изменений; это запасное обновление,
        // в том числе чтобы после полуночи «сегодня» обнулилось.
        let calendar = Calendar.current
        let nextMidnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let next = min(Date.now.addingTimeInterval(30 * 60), nextMidnight.addingTimeInterval(60))
        return Timeline(entries: [entry], policy: .after(next))
    }
}

struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetSnapshotStore.widgetKind, intent: BalanceConfigIntent.self, provider: BalanceProvider()) { entry in
            BalanceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Баланс")
        .description("Учёба, отдых и сон по факту против цели. Период выбирается в настройках виджета.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceEntry
    @Environment(\.widgetFamily) private var family

    private struct Row: Identifiable {
        let id: String
        let title: String
        let fact: Int
        let target: Int
        let color: Color
    }

    private var rows: [Row] {
        let snapshot = entry.snapshot
        let todayKey = Self.key(for: entry.date)
        let isCurrent = snapshot?.dayKey == todayKey
        let source: BalanceMinutes
        let multiplier: Int
        switch entry.period {
        case .today:
            source = isCurrent ? (snapshot?.today ?? BalanceMinutes()) : BalanceMinutes()
            multiplier = 1
        case .week:
            source = snapshot?.week ?? BalanceMinutes()
            multiplier = max(snapshot?.weekDaysElapsed ?? 1, 1)
        }
        let target = snapshot?.target ?? BalanceMinutes(study: 360, rest: 180, sleep: 480)
        return [
            Row(id: "study", title: "Учёба", fact: source.study, target: target.study * multiplier, color: Color(red: 0.42, green: 0.36, blue: 0.91)),
            Row(id: "rest", title: "Отдых", fact: source.rest, target: target.rest * multiplier, color: Color(red: 0.42, green: 0.69, blue: 0.30)),
            Row(id: "sleep", title: "Сон", fact: source.sleep, target: target.sleep * multiplier, color: Color(red: 0.24, green: 0.39, blue: 0.51)),
        ]
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                ForEach(rows) { row in
                    Text("\(row.title) \(Self.hours(row.fact))/\(Self.hours(row.target))")
                        .font(.caption2)
                }
            }
        default:
            VStack(alignment: .leading, spacing: family == .systemMedium ? 8 : 6) {
                Text(entry.period == .today ? "Баланс · сегодня" : "Баланс · неделя")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.title)
                            Spacer()
                            Text("\(Self.hours(row.fact)) / \(Self.hours(row.target))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption2)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(row.color.opacity(0.2))
                                Capsule().fill(row.color)
                                    .frame(width: geometry.size.width * min(1, Double(row.fact) / Double(max(row.target, 1))))
                            }
                        }
                        .frame(height: family == .systemMedium ? 8 : 6)
                    }
                }
                if entry.snapshot == nil {
                    Text("Открой приложение, чтобы виджет получил данные")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    static func hours(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60
        if hours == hours.rounded() { return "\(Int(hours)) ч" }
        return String(format: "%.1f ч", hours).replacingOccurrences(of: ".", with: ",")
    }

    static func key(for date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}

extension WidgetSnapshot {
    static let preview = WidgetSnapshot(
        writtenAt: .now,
        dayKey: BalanceWidgetView.key(for: .now),
        today: BalanceMinutes(study: 240, rest: 90, sleep: 450),
        week: BalanceMinutes(study: 900, rest: 500, sleep: 1800),
        weekDaysElapsed: 3,
        target: BalanceMinutes(study: 360, rest: 180, sleep: 480)
    )
}
