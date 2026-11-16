import Charts
import DayTrackCore
import SwiftData
import SwiftUI

/// Графики за неделю или месяц.
struct PeriodAnalyticsView: View {
    let range: ClosedRange<Int>
    let kind: PeriodKind
    let onSelectDay: (Int) -> Void

    @Query private var days: [Day]
    @Query private var marks: [EnergyMark]
    @Query(sort: \Focus.sortOrder) private var allFocuses: [Focus]

    init(range: ClosedRange<Int>, kind: PeriodKind, onSelectDay: @escaping (Int) -> Void) {
        self.range = range
        self.kind = kind
        self.onSelectDay = onSelectDay
        let from = range.lowerBound
        let to = range.upperBound
        _days = Query(filter: #Predicate<Day> { $0.key >= from && $0.key <= to })
        _marks = Query(filter: #Predicate<EnergyMark> { $0.dayKey >= from && $0.dayKey <= to })
    }

    var body: some View {
        let data = PeriodAnalytics(range: range, kind: kind, days: days, marks: marks)

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                summaryCard(data)

                ChartCard(title: kind == .month ? "Календарь" : "Дни недели") {
                    HeatmapCalendar(points: data.days, onSelect: onSelectDay)
                }

                if !data.daysWithPlan.isEmpty {
                    ChartCard(title: "Выполнение плана по дням") { completionChart(data) }
                }

                if data.totalFactMinutes > 0 {
                    ChartCard(title: "Баланс по дням, часы") { balanceChart(data) }
                    ChartCard(title: "Куда ушло время") { distributionChart(data) }
                }

                if data.categories.contains(where: { $0.planned > 0 }) {
                    ChartCard(title: "План и факт по категориям, часы") { planFactChart(data) }
                }

                let focuses = focusLines(data)
                if !focuses.isEmpty {
                    ChartCard(title: "Фокусы") { focusList(focuses) }
                }

                if !data.reasons.isEmpty {
                    ChartCard(title: "Что сбивало с плана") { reasonsList(data) }
                }

                let estimates = data.categories.filter { ($0.estimateRatio ?? 0) > 0 }
                if !estimates.isEmpty {
                    ChartCard(title: "Точность оценок времени") { estimatesList(estimates) }
                }

                if !data.energyByHour.isEmpty {
                    ChartCard(title: "Энергия и настроение по часам") { energyChart(data) }
                }

                if data.totalFactMinutes == 0 && data.daysWithPlan.isEmpty {
                    Text("За этот период пока нет ни плана, ни факта.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
    }

    // MARK: Итоги

    private func summaryCard(_ data: PeriodAnalytics) -> some View {
        let groups = BalanceGroup.minutes(data.byKind)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(data.completion.map(DurationText.percent) ?? "—")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("плана выполнено")
                    .foregroundStyle(.secondary)
            }
            Text("Дней с планом: \(data.daysWithPlan.count) из \(data.days.count) · отмечено \(DurationText.short(minutes: data.totalFactMinutes))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(BalanceGroup.allCases, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(hours(groups[group] ?? 0))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(group.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Графики

    private func completionChart(_ data: PeriodAnalytics) -> some View {
        Chart {
            ForEach(data.days.filter(\.hasPlan)) { point in
                BarMark(
                    x: .value("День", point.label),
                    y: .value("Выполнение", (point.completion ?? 0) * 100)
                )
                .foregroundStyle(HeatmapCalendar.heat(point.completion ?? 0))
            }
            if let average = data.completion {
                RuleMark(y: .value("Среднее", average * 100))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("в среднем \(DurationText.percent(average))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis { AxisMarks(values: [0, 50, 100]) { value in
            AxisGridLine()
            AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
        } }
        .frame(height: 180)
    }

    private func balanceChart(_ data: PeriodAnalytics) -> some View {
        Chart {
            ForEach(data.days) { point in
                let groups = BalanceGroup.minutes(point.byKind)
                ForEach(BalanceGroup.allCases, id: \.self) { group in
                    if let minutes = groups[group], minutes > 0 {
                        BarMark(
                            x: .value("День", point.label),
                            y: .value("Часы", Double(minutes) / 60)
                        )
                        .foregroundStyle(by: .value("Тип", group.rawValue))
                    }
                }
            }
        }
        .chartForegroundStyleScale(
            domain: BalanceGroup.allCases.map(\.rawValue),
            range: BalanceGroup.allCases.map(\.color)
        )
        .chartLegend(position: .bottom)
        .frame(height: 200)
    }

    private func distributionChart(_ data: PeriodAnalytics) -> some View {
        let lines = data.categories.filter { $0.fact > 0 }
        let total = max(lines.reduce(0) { $0 + $1.fact }, 1)
        return HStack(alignment: .center, spacing: 16) {
            Chart(lines) { line in
                SectorMark(
                    angle: .value("Минуты", line.fact),
                    innerRadius: .ratio(0.6),
                    angularInset: 1
                )
                .foregroundStyle(line.color)
            }
            .frame(width: 130, height: 130)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines.prefix(7)) { line in
                    HStack(spacing: 6) {
                        Circle().fill(line.color).frame(width: 8, height: 8)
                        Text(line.name)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(DurationText.percent(Double(line.fact) / Double(total)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func planFactChart(_ data: PeriodAnalytics) -> some View {
        let lines = Array(data.categories.prefix(8))
        return Chart {
            ForEach(lines) { line in
                BarMark(x: .value("Часы", Double(line.planned) / 60), y: .value("Категория", line.name))
                    .foregroundStyle(by: .value("Тип", "План"))
                    .position(by: .value("Тип", "План"))
                BarMark(x: .value("Часы", Double(line.fact) / 60), y: .value("Категория", line.name))
                    .foregroundStyle(by: .value("Тип", "Факт"))
                    .position(by: .value("Тип", "Факт"))
            }
        }
        .chartForegroundStyleScale(["План": Color.gray.opacity(0.45), "Факт": Color.accentColor])
        .chartLegend(position: .bottom)
        .frame(height: CGFloat(lines.count) * 44 + 40)
    }

    private func energyChart(_ data: PeriodAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(HourValue.list(data.energyByHour)) { item in
                    LineMark(x: .value("Час", item.hour), y: .value("Значение", item.value), series: .value("Тип", "Энергия"))
                        .foregroundStyle(by: .value("Тип", "Энергия"))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Час", item.hour), y: .value("Значение", item.value))
                        .foregroundStyle(by: .value("Тип", "Энергия"))
                }
                ForEach(HourValue.list(data.moodByHour)) { item in
                    LineMark(x: .value("Час", item.hour), y: .value("Значение", item.value), series: .value("Тип", "Настроение"))
                        .foregroundStyle(by: .value("Тип", "Настроение"))
                        .interpolationMethod(.monotone)
                }
            }
            .chartForegroundStyleScale(["Энергия": Color.orange, "Настроение": Color.teal])
            .chartXScale(domain: 0...23)
            .chartYScale(domain: 1...5)
            .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) }
            .frame(height: 170)

            if !data.bestEnergyHours.isEmpty {
                Text("Больше всего сил: \(data.bestEnergyHours.map { "\($0):00" }.joined(separator: ", ")). Сложные дела лучше ставить на эти часы.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Списки

    private func reasonsList(_ data: PeriodAnalytics) -> some View {
        let maxCount = data.reasons.first?.count ?? 1
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(data.reasons.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Text(item.reason.title)
                        .font(.subheadline)
                        .frame(width: 150, alignment: .leading)
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: geometry.size.width * CGFloat(item.count) / CGFloat(maxCount))
                    }
                    .frame(height: 10)
                    Text("\(item.count)")
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }
        }
    }

    private func estimatesList(_ lines: [PeriodAnalytics.CategoryLine]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines) { line in
                let ratio = line.estimateRatio ?? 1
                let percent = Int(((ratio - 1) * 100).rounded())
                HStack {
                    Circle().fill(line.color).frame(width: 8, height: 8)
                    Text(line.name)
                    Spacer()
                    Text(percent == 0 ? "точно" : (percent > 0 ? "дольше на \(percent)%" : "быстрее на \(-percent)%"))
                        .foregroundStyle(percent > 20 ? .orange : .secondary)
                }
                .font(.subheadline)
            }
            Text("Сравнение факта с планом по блокам, которые были выполнены. Если дела стабильно занимают больше, закладывай на них больше времени.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private struct FocusLine: Identifiable {
        var id: UUID
        var title: String
        var period: FocusPeriod
        var status: FocusStatus
        var progress: FocusProgress
    }

    private func focusLines(_ data: PeriodAnalytics) -> [FocusLine] {
        let related = allFocuses.filter { $0.range.overlaps(range) }
        guard !related.isEmpty else { return [] }
        let progress = FocusProgress.compute(focuses: related, days: days)
        return related.map {
            FocusLine(id: $0.uuid, title: $0.title, period: $0.period, status: $0.status,
                      progress: progress[$0.uuid] ?? FocusProgress())
        }
        .sorted { $0.progress.minutes > $1.progress.minutes }
    }

    private func focusList(_ lines: [FocusLine]) -> some View {
        let maxMinutes = max(lines.map(\.progress.minutes).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(lines) { line in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(line.title)
                            .font(.subheadline)
                        Spacer()
                        Text(line.progress.text)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor.opacity(line.period == .week ? 0.8 : 0.45))
                            .frame(width: max(4, geometry.size.width * CGFloat(line.progress.minutes) / CGFloat(maxMinutes)))
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    private func hours(_ minutes: Int) -> String {
        DurationText.short(minutes: minutes)
    }
}

/// Карточка с заголовком для графика.
struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Значение для часа суток.
struct HourValue: Identifiable {
    var hour: Int
    var value: Double
    var id: Int { hour }

    static func list(_ values: [Int: Double]) -> [HourValue] {
        values.map { HourValue(hour: $0.key, value: $0.value) }.sorted { $0.hour < $1.hour }
    }
}
