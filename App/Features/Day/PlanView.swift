import DayTrackCore
import SwiftData
import SwiftUI

/// Вкладка «План»: состояние плана, задачи без времени и шкала блоков.
struct PlanView: View {
    let dayKey: Int

    @Environment(\.modelContext) private var context
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

    private var store: DayStore { DayStore(context: context) }
    private var day: Day? { days.first }
    private var isToday: Bool { clock.key(for: .now) == dayKey }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            content(now: timeline.date)
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton(label: "Добавить блок плана") {
                sheet = DaySheet(kind: .newBlock(start: defaultStart()))
            }
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
                    PlanStatusCard(
                        day: day,
                        plannedMinutes: summary.current.plannedMinutes,
                        breakdown: categoryBreakdown,
                        canUnlock: day.map { store.canUnlock($0) } ?? false,
                        onLock: { if let day { store.lock(day) } },
                        onUnlock: { if let day { store.unlock(day) } }
                    )

                    TasksCard(
                        tasks: (day?.tasks ?? []).sorted { $0.sortOrder < $1.sortOrder },
                        onAdd: { store.addTask(dayKey: dayKey, title: $0) },
                        onToggle: { store.toggleTask($0) },
                        onDelete: { store.deleteTask($0) }
                    )

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
                                        },
                                        onTapSpace: { sheet = DaySheet(kind: .newBlock(start: $0)) }
                                    )
                                ],
                                now: isToday ? now : nil,
                                hourHeight: 30
                            )
                            .padding(.top, 8)
                        } header: {
                            TimelineColumnsHeader(titles: ["План"])
                        }
                    }

                    if let day, !day.changes.isEmpty {
                        PlanChangesCard(changes: day.changes.sorted { $0.at < $1.at })
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
            .task {
                guard let window = clock.window(forKey: dayKey) else { return }
                try? await Task.sleep(for: .milliseconds(150))
                let hour = TimelineScroll.initialHour(
                    window: window, isToday: isToday,
                    starts: day?.activeBlocks.map(\.start) ?? []
                )
                proxy.scrollTo(TimelineGridView.hourAnchor(hour), anchor: .top)
            }
        }
    }

    /// Сколько времени запланировано на каждую категорию, по убыванию.
    private var categoryBreakdown: [CategoryMinutes] {
        var totals: [String: CategoryMinutes] = [:]
        for block in day?.activeBlocks ?? [] {
            let key = block.category?.uuid.uuidString ?? "none"
            let minutes = PlanComparison.minutes(from: block.start, to: block.end)
            totals[key, default: CategoryMinutes(
                name: block.category?.name ?? "Без категории",
                colorHex: block.category?.colorHex ?? "7F8C8D",
                minutes: 0
            )].minutes += minutes
        }
        return totals.values.sorted { $0.minutes > $1.minutes }
    }

    private func planItems(summary: DaySummary, window: DateInterval) -> [TimelineItem] {
        let carried = (previousDays.first?.activeBlocks ?? [])
            .filter { $0.end > window.start }
            .map { TimelineItem.plan($0, result: nil, isGhost: true) }
        let own = (day?.activeBlocks ?? []).map { TimelineItem.plan($0, result: summary.status(of: $0)) }
        return carried + own
    }

    /// Начало нового блока: сразу после последнего блока, иначе ближайший час
    /// сегодня или 9:00 в другой день.
    private func defaultStart() -> Date {
        if let lastEnd = day?.activeBlocks.map(\.end).max(),
           let window = clock.window(forKey: dayKey), lastEnd < window.end {
            return lastEnd
        }
        if isToday {
            let hour = clock.calendar.component(.hour, from: Date.now.addingTimeInterval(3600))
            if let date = clock.resolve(hour: hour, minute: 0, inDay: dayKey) { return date }
        }
        return clock.resolve(hour: 9, minute: 0, inDay: dayKey) ?? .now
    }
}
