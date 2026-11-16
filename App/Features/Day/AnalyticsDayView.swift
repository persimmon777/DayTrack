import DayTrackCore
import SwiftData
import SwiftUI

/// План и факт дня рядом. Графики и календарь появятся здесь на этапе 2.
struct AnalyticsDayView: View {
    let dayKey: Int

    @Query private var days: [Day]
    @Query private var previousDays: [Day]

    @State private var sheet: DaySheet?

    private let clock = DayClock.app

    init(dayKey: Int) {
        self.dayKey = dayKey
        let previousKey = DayClock.app.key(byAdding: -1, to: dayKey)
        _days = Query(filter: #Predicate<Day> { $0.key == dayKey })
        _previousDays = Query(filter: #Predicate<Day> { $0.key == previousKey })
    }

    private var day: Day? { days.first }
    private var isToday: Bool { clock.key(for: .now) == dayKey }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            content(now: timeline.date)
        }
        .sheet(item: $sheet) { item in
            DaySheetView(sheet: item, dayKey: dayKey) { sheet = $0 }
        }
    }

    private func content(now: Date) -> some View {
        let summary = DaySummary(day: day, now: now)

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                    ComparisonCard(day: day, summary: summary)

                    if let window = clock.window(forKey: dayKey) {
                        Section {
                            TimelineGridView(
                                window: window,
                                columns: [
                                    TimelineColumn(
                                        items: planItems(summary: summary, window: window),
                                        onTapItem: { id in
                                            if let block = day?.blocks.first(where: { $0.uuid == id }) {
                                                sheet = DaySheet(kind: .blockDetail(block))
                                            }
                                        }
                                    ),
                                    TimelineColumn(
                                        items: factItems(window: window),
                                        onTapItem: { id in
                                            if let fact = day?.facts.first(where: { $0.uuid == id }) {
                                                sheet = DaySheet(kind: .editFact(fact))
                                            }
                                        }
                                    ),
                                ],
                                now: isToday ? now : nil
                            )
                            .padding(.top, 8)
                        } header: {
                            TimelineColumnsHeader(titles: ["План", "Факт"])
                        }
                    }

                    if let day, !day.changes.isEmpty {
                        PlanChangesCard(changes: day.changes.sorted { $0.at < $1.at })
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
            .task {
                guard let window = clock.window(forKey: dayKey) else { return }
                try? await Task.sleep(for: .milliseconds(150))
                let starts = (day?.activeBlocks.map(\.start) ?? []) + (day?.facts.map(\.start) ?? [])
                let hour = TimelineScroll.initialHour(window: window, isToday: isToday, starts: starts)
                proxy.scrollTo(TimelineGridView.hourAnchor(hour), anchor: .top)
            }
        }
    }

    private func planItems(summary: DaySummary, window: DateInterval) -> [TimelineItem] {
        let carried = (previousDays.first?.activeBlocks ?? [])
            .filter { $0.end > window.start }
            .map { TimelineItem.plan($0, result: nil, isGhost: true) }
        let own = (day?.activeBlocks ?? []).map { TimelineItem.plan($0, result: summary.status(of: $0)) }
        return carried + own
    }

    private func factItems(window: DateInterval) -> [TimelineItem] {
        let carried = (previousDays.first?.facts ?? [])
            .filter { $0.end > window.start }
            .map { TimelineItem.fact($0, isGhost: true) }
        let own = (day?.facts ?? []).map { TimelineItem.fact($0) }
        return carried + own
    }
}
