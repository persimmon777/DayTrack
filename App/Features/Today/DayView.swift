import DayTrackCore
import SwiftData
import SwiftUI

/// Что открыто поверх экрана дня.
struct DaySheet: Identifiable {
    enum Kind {
        case newBlock(start: Date)
        case editBlock(PlannedBlock)
        case blockDetail(PlannedBlock)
        case newFact(block: PlannedBlock?, start: Date?)
        case editFact(FactEntry)
    }

    // Отдельный идентификатор, не зависящий от записи: к удалённой записи
    // обращаться нельзя, а окно в этот момент ещё закрывается.
    let id = UUID()
    let kind: Kind
}

/// Экран одного дня: итоги, задачи без времени и две шкалы времени.
struct DayView: View {
    let dayKey: Int

    @Environment(\.modelContext) private var context
    @Query private var days: [Day]
    @Query private var previousDays: [Day]
    @Query(sort: \ActivityCategory.sortOrder) private var categories: [ActivityCategory]

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
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let summary = DaySummary(day: day, now: now)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                    DayHeaderCard(
                        day: day,
                        summary: summary,
                        canUnlock: day.map { store.canUnlock($0) } ?? false,
                        onLock: { if let day { store.lock(day) } },
                        onUnlock: { if let day { store.unlock(day) } },
                        onAddBlock: { sheet = DaySheet(kind: .newBlock(start: defaultStart(now: now))) },
                        onAddUnplanned: { sheet = DaySheet(kind: .newFact(block: nil, start: nil)) }
                    )

                    TasksCard(
                        tasks: (day?.tasks ?? []).sorted { $0.sortOrder < $1.sortOrder },
                        onAdd: { store.addTask(dayKey: dayKey, title: $0) },
                        onToggle: { store.toggleTask($0) },
                        onDelete: { store.deleteTask($0) }
                    )

                    if let window = clock.window(forKey: dayKey) {
                        Section {
                            DualTimelineView(
                                window: window,
                                planItems: planItems(summary: summary, window: window),
                                factItems: factItems(window: window),
                                now: isToday ? now : nil,
                                onTapPlanItem: { id in
                                    if let block = day?.blocks.first(where: { $0.uuid == id }) {
                                        sheet = DaySheet(kind: .blockDetail(block))
                                    }
                                },
                                onTapFactItem: { id in
                                    if let fact = day?.facts.first(where: { $0.uuid == id }) {
                                        sheet = DaySheet(kind: .editFact(fact))
                                    }
                                },
                                onTapPlanSpace: { sheet = DaySheet(kind: .newBlock(start: $0)) },
                                onTapFactSpace: { sheet = DaySheet(kind: .newFact(block: nil, start: $0)) }
                            )
                            .padding(.top, 8)
                        } header: {
                            TimelineColumnsHeader()
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
                // Шкала длинная, поэтому экран открывается на нужном часе.
                try? await Task.sleep(for: .milliseconds(150))
                proxy.scrollTo(DualTimelineView.hourAnchor(initialHourIndex()), anchor: .top)
            }
        }
    }

    // MARK: Данные для шкалы

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

    /// Час, на котором открывается шкала: сейчас для сегодняшнего дня,
    /// иначе первый блок, иначе 8 утра.
    private func initialHourIndex() -> Int {
        guard let window = clock.window(forKey: dayKey) else { return 0 }
        let anchor: Date
        if isToday {
            anchor = Date.now.addingTimeInterval(-3600)
        } else if let first = ((day?.activeBlocks.map(\.start) ?? []) + (day?.facts.map(\.start) ?? [])).min() {
            anchor = first
        } else {
            anchor = clock.resolve(hour: 8, minute: 0, inDay: dayKey) ?? window.start
        }
        let hours = Int(anchor.timeIntervalSince(window.start) / 3600)
        return min(max(hours, 0), 23)
    }

    /// Время начала для блока, добавляемого кнопкой: ближайший час сегодня или 9:00.
    private func defaultStart(now: Date) -> Date {
        if isToday {
            let parts = clock.calendar.dateComponents([.hour], from: now.addingTimeInterval(3600))
            if let date = clock.resolve(hour: parts.hour ?? 9, minute: 0, inDay: dayKey) { return date }
        }
        return clock.resolve(hour: 9, minute: 0, inDay: dayKey) ?? now
    }

    // MARK: Окна

    @ViewBuilder
    private func sheetContent(_ sheet: DaySheet) -> some View {
        switch sheet.kind {
        case .newBlock(let start):
            BlockEditorSheet(dayKey: dayKey, mode: .new(start: start), categories: categories) { _ in }
        case .editBlock(let block):
            BlockEditorSheet(dayKey: dayKey, mode: .edit(block), categories: categories) { action in
                if action == .delete { deleteAfterDismiss { store.deleteBlock(block) } }
            }
        case .blockDetail(let block):
            BlockDetailSheet(
                block: block,
                result: DaySummary(day: day, now: .now).status(of: block),
                onAddFact: { self.sheet = DaySheet(kind: .newFact(block: block, start: nil)) },
                onEdit: { self.sheet = DaySheet(kind: .editBlock(block)) },
                onEditFact: { self.sheet = DaySheet(kind: .editFact($0)) },
                onDelete: { deleteAfterDismiss { store.deleteBlock(block) } }
            )
        case .newFact(let block, let start):
            FactEditorSheet(dayKey: dayKey, mode: .new(block: block, start: start), categories: categories) { _ in }
        case .editFact(let fact):
            FactEditorSheet(dayKey: dayKey, mode: .edit(fact), categories: categories) { action in
                if action == .delete { deleteAfterDismiss { store.deleteFact(fact) } }
            }
        }
    }

    /// Запись удаляется после того, как окно закрылось: пока оно закрывается,
    /// оно ещё показывает эту запись.
    private func deleteAfterDismiss(_ delete: @escaping @MainActor () -> Void) {
        sheet = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            delete()
        }
    }
}

/// Чем закончилось редактирование в окне.
enum EditorAction {
    case save
    case delete
}
