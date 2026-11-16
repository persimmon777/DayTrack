import DayTrackCore
import SwiftUI

/// Календарь периода: цвет дня — выполнение плана. Нажатие открывает день.
struct HeatmapCalendar: View {
    let points: [PeriodAnalytics.DayPoint]
    let onSelect: (Int) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdayTitles = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

    /// Пустые клетки перед первым днём, чтобы понедельник был в первом столбце.
    private var leadingBlanks: Int {
        guard let first = points.first,
              let date = Recurrence.date(forKey: first.key, calendar: calendar) else { return 0 }
        return (calendar.component(.weekday, from: date) + 5) % 7
    }

    private var todayKey: Int { DayClock.app.key(for: .now) }

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                ForEach(points) { point in
                    Button {
                        onSelect(point.key)
                    } label: {
                        cell(point)
                    }
                    .buttonStyle(.plain)
                }
            }
            legend
        }
    }

    private func cell(_ point: PeriodAnalytics.DayPoint) -> some View {
        let day = point.key % 100
        return VStack(spacing: 1) {
            Text("\(day)")
                .font(.footnote.weight(point.key == todayKey ? .bold : .regular))
            if let completion = point.completion, point.key <= todayKey {
                Text(DurationText.percent(completion))
                    .font(.system(size: 9))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(color(point), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            if point.key == todayKey {
                RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 1.5)
            }
        }
        .overlay(alignment: .topTrailing) {
            // План есть, а факт не внесён.
            if point.hasPlan, !point.hasFact, point.key < todayKey {
                Circle().fill(.orange).frame(width: 5, height: 5).padding(3)
            }
        }
    }

    private func color(_ point: PeriodAnalytics.DayPoint) -> Color {
        guard let completion = point.completion, point.key <= todayKey else {
            return point.hasFact ? Color(.systemGray5) : Color(.systemGray6)
        }
        return Self.heat(completion)
    }

    static func heat(_ completion: Double) -> Color {
        let value = min(max(completion, 0), 1)
        if value < 0.4 { return Color.red.opacity(0.25 + value) }
        if value < 0.7 { return Color.orange.opacity(0.35 + (value - 0.4)) }
        return Color.green.opacity(0.3 + (value - 0.7) * 1.5)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendItem(Self.heat(0.2), "до 40%")
            legendItem(Self.heat(0.55), "40–70%")
            legendItem(Self.heat(0.9), "от 70%")
            HStack(spacing: 4) {
                Circle().fill(.orange).frame(width: 6, height: 6)
                Text("нет факта")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(title)
        }
    }
}
