import DayTrackCore
import SwiftData
import SwiftUI

/// Вкладка «План»: состояние плана, задачи без времени и шкала блоков.
struct PlanView: View {
    let dayKey: Int

    @Environment(\.modelContext) private var context
    @Query private var days: [Day]
    @Query private var previousDays: [Day]
    @Query(sort: \Reminder.firstDayKey) private var reminders: [Reminder]
    @Query(sort: \DayTemplate.createdAt) private var templates: [DayTemplate]

    @State private var sheet: DaySheet?
    @State private var isNamingTemplate = false
    @State private var templateName = ""
    @State private var notice: String?

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
            FloatingAddMenu(label: "Добавить") {
                Button {
                    sheet = DaySheet(kind: .newBlock(start: defaultStart()))
                } label: {
                    Label("Блок плана", systemImage: "rectangle.stack.badge.plus")
                }
                Button {
                    sheet = DaySheet(kind: .reminder(nil))
                } label: {
                    Label("Напоминание или событие", systemImage: "bell.badge")
                }
                Button {
                    sheet = DaySheet(kind: .restStart)
                } label: {
                    Label("Начать отдых", systemImage: "cup.and.saucer")
                }
                Divider()
                Button {
                    let added = store.applySchedule(dayKey: dayKey)
                    notice = added == 0
                        ? "В расписании нет занятий на этот день, которых ещё нет в плане."
                        : "Добавлено занятий из расписания: \(added)."
                } label: {
                    Label("Подставить расписание", systemImage: "calendar.badge.clock")
                }
                if !templates.isEmpty {
                    Menu {
                        ForEach(templates) { template in
                            Button(template.name) { store.applyTemplate(template, dayKey: dayKey) }
                        }
                    } label: {
                        Label("Применить шаблон", systemImage: "square.on.square")
                    }
                }
                if !(day?.activeBlocks.isEmpty ?? true) {
                    Button {
                        templateName = ""
                        isNamingTemplate = true
                    } label: {
                        Label("Сохранить день как шаблон", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .alert("Название шаблона", isPresented: $isNamingTemplate) {
            TextField("Например: учебный день", text: $templateName)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить") {
                let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let day, !name.isEmpty { store.saveTemplate(named: name, from: day) }
            }
        }
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("Понятно", role: .cancel) {}
        }
        .onAppear {
            store.autoApplySchedule(dayKey: dayKey)
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
                    RestBanner()

                    FocusStrip(dayKey: dayKey)

                    PlanStatusCard(
                        day: day,
                        plannedMinutes: summary.current.plannedMinutes,
                        breakdown: categoryBreakdown,
                        canUnlock: day.map { store.canUnlock($0) } ?? false,
                        onLock: { if let day { store.lock(day) } },
                        onUnlock: { if let day { store.unlock(day) } }
                    )

                    RemindersCard(
                        today: dayReminders,
                        upcoming: isToday ? upcomingReminders : [],
                        onTap: { sheet = DaySheet(kind: .reminder($0)) }
                    )

                    TasksCard(
                        tasks: (day?.tasks ?? []).sorted { $0.sortOrder < $1.sortOrder },
                        onAdd: { store.addTask(dayKey: dayKey, title: $0) },
                        onToggle: { store.toggleTask($0) },
                        onEdit: { sheet = DaySheet(kind: .editTask($0)) },
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

    /// Напоминания этого дня: сначала на весь день, потом по времени.
    private var dayReminders: [Reminder] {
        reminders
            .filter { $0.occurs(onDayKey: dayKey) }
            .sorted { ($0.minuteOfDay ?? -1) < ($1.minuteOfDay ?? -1) }
    }

    /// Напоминания на ближайшую неделю после сегодняшнего дня.
    private var upcomingReminders: [(dayKey: Int, reminder: Reminder)] {
        let calendar = Calendar.current
        let from = Recurrence.key(dayKey, addingDays: 1, calendar: calendar)
        let through = Recurrence.key(dayKey, addingDays: 7, calendar: calendar)
        var result: [(dayKey: Int, reminder: Reminder)] = []
        for reminder in reminders {
            let days = Recurrence.occurrences(
                first: reminder.firstDayKey, rule: reminder.repeatRule,
                from: from, through: through, calendar: calendar
            )
            result += days.map { ($0, reminder) }
        }
        return result.sorted { ($0.dayKey, $0.reminder.minuteOfDay ?? -1) < ($1.dayKey, $1.reminder.minuteOfDay ?? -1) }
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

/// Напоминания дня и ближайшие события.
private struct RemindersCard: View {
    let today: [Reminder]
    let upcoming: [(dayKey: Int, reminder: Reminder)]
    let onTap: (Reminder) -> Void

    var body: some View {
        if !today.isEmpty || !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !today.isEmpty {
                    Text("Напоминания")
                        .font(.subheadline.weight(.semibold))
                    ForEach(today) { reminder in
                        Button { onTap(reminder) } label: { ReminderRow(reminder: reminder) }
                            .foregroundStyle(.primary)
                    }
                }
                if !upcoming.isEmpty {
                    Text("Скоро")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, today.isEmpty ? 0 : 4)
                    ForEach(Array(upcoming.enumerated()), id: \.offset) { _, item in
                        Button { onTap(item.reminder) } label: {
                            ReminderRow(reminder: item.reminder, dateText: dateText(item.dayKey))
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func dateText(_ key: Int) -> String {
        let calendar = Calendar.current
        let today = Recurrence.keyOf(.now, calendar: calendar)
        if key == Recurrence.key(today, addingDays: 1, calendar: calendar) { return "завтра" }
        return Recurrence.date(forKey: key, calendar: calendar).map(Format.day) ?? ""
    }
}
