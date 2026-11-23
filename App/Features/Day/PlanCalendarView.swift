import DayTrackCore
import SwiftData
import SwiftUI

/// Календарь планов на месяц: над числом — сколько дел, под ним — начало первых двух.
/// Нажатие на день показывает его план и даёт добавить новый блок.
struct PlanCalendarView: View {
    /// Открыть день в «Плане».
    let onOpenDay: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var monthKey: Int
    @State private var selectedKey: Int

    private let calendar = Calendar.current

    init(dayKey: Int, onOpenDay: @escaping (Int) -> Void) {
        self.onOpenDay = onOpenDay
        _monthKey = State(initialValue: dayKey)
        _selectedKey = State(initialValue: dayKey)
    }

    private var range: ClosedRange<Int> { Periods.range(.month, containing: monthKey, calendar: calendar) }

    var body: some View {
        NavigationStack {
            PlanCalendarMonth(range: range, selectedKey: $selectedKey) { key in
                onOpenDay(key)
                dismiss()
            }
            .id(range.lowerBound)
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        monthKey = Periods.shift(monthKey, kind: .month, by: -1, calendar: calendar)
                    } label: { Image(systemName: "chevron.left") }
                    Button {
                        monthKey = Periods.shift(monthKey, kind: .month, by: 1, calendar: calendar)
                    } label: { Image(systemName: "chevron.right") }
                }
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Format.locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Recurrence.date(forKey: monthKey, calendar: calendar) ?? .now).capitalized
    }
}

/// Сетка месяца и план выбранного дня.
private struct PlanCalendarMonth: View {
    let range: ClosedRange<Int>
    @Binding var selectedKey: Int
    let onOpenDay: (Int) -> Void

    @Environment(\.modelContext) private var context
    @Query private var days: [Day]
    @Query private var reminders: [Reminder]
    @Query private var rules: [ScheduleRule]
    @Query(sort: \ActivityCategory.sortOrder) private var categories: [ActivityCategory]

    @State private var sheet: DaySheet?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdayTitles = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

    init(range: ClosedRange<Int>, selectedKey: Binding<Int>, onOpenDay: @escaping (Int) -> Void) {
        self.range = range
        _selectedKey = selectedKey
        self.onOpenDay = onOpenDay
        let from = range.lowerBound, to = range.upperBound
        _days = Query(filter: #Predicate<Day> { $0.key >= from && $0.key <= to })
    }

    private var todayKey: Int { DayClock.app.key(for: .now) }

    /// Запланированное на день: блоки, а для будущих дней без подставленного расписания — занятия из него.
    private struct Entry: Identifiable {
        let id: String
        let start: Date?
        let title: String
        let colorHex: String
        let isReminder: Bool
    }

    private func entries(for key: Int) -> [Entry] {
        let day = days.first { $0.key == key }
        var result: [Entry] = (day?.activeBlocks ?? []).map {
            Entry(id: $0.uuid.uuidString, start: $0.start, title: $0.title,
                  colorHex: $0.category?.colorHex ?? "7F8C8D", isReminder: false)
        }
        let scheduleApplies = key >= todayKey && !(day?.scheduleApplied ?? false) && !(day?.isLocked ?? false)
        if scheduleApplies {
            let firstWeek = ScheduleSettings.firstWeekKey
            for rule in rules where WeeklySchedule.applies(rule.data, on: key, firstWeekKey: firstWeek, calendar: calendar) {
                let start = DayClock.app.resolve(hour: rule.startMinute / 60, minute: rule.startMinute % 60, inDay: key)
                let color = categories.first { $0.uuid == rule.categoryUUID }?.colorHex ?? "7F8C8D"
                result.append(Entry(id: "rule-\(rule.uuid)", start: start, title: rule.title, colorHex: color, isReminder: false))
            }
        }
        for reminder in reminders where reminder.occurs(onDayKey: key) {
            let start = reminder.minuteOfDay.flatMap {
                DayClock.app.resolve(hour: $0 / 60, minute: $0 % 60, inDay: key)
            }
            result.append(Entry(id: "rem-\(reminder.uuid)", start: start, title: reminder.title,
                                colorHex: "F0932B", isReminder: true))
        }
        return result.sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
    }

    private var leadingBlanks: Int {
        guard let date = Recurrence.date(forKey: range.lowerBound, calendar: calendar) else { return 0 }
        return (calendar.component(.weekday, from: date) + 5) % 7
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(weekdayTitles, id: \.self) {
                        Text($0).font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 76) }
                    ForEach(Periods.days(in: range, calendar: calendar), id: \.self) { key in
                        cell(key)
                            .onTapGesture { selectedKey = key }
                    }
                }
                .padding(.horizontal, 6)

                selectedDayCard
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
        }
        .sheet(item: $sheet) { item in
            DaySheetView(sheet: item, dayKey: selectedKey) { sheet = $0 }
        }
        .onAppear {
            if !range.contains(selectedKey) {
                selectedKey = range.contains(todayKey) ? todayKey : range.lowerBound
            }
        }
    }

    private func cell(_ key: Int) -> some View {
        let items = entries(for: key)
        let timed = items.filter { $0.start != nil && !$0.isReminder }
        let isSelected = key == selectedKey
        let isToday = key == todayKey
        return VStack(spacing: 2) {
            // Сколько дел запланировано.
            Text(items.isEmpty ? " " : "\(items.count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(items.isEmpty ? Color.clear : Color.accentColor)
                .frame(height: 12)
            Text("\(key % 100)")
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .frame(width: 30, height: 30)
                .background {
                    Circle().fill(isSelected ? Color.accentColor : Color.clear)
                }
                .overlay {
                    if isToday && !isSelected { Circle().stroke(Color.accentColor, lineWidth: 1.5) }
                }
                .foregroundStyle(isSelected ? Color.white : (key < todayKey ? Color.secondary : Color.primary))
            // Начало первых двух дел.
            VStack(spacing: 0) {
                ForEach(timed.prefix(2)) { entry in
                    Text(Format.time(entry.start ?? .now))
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: entry.colorHex))
                }
                if items.contains(where: \.isReminder) && timed.count < 2 {
                    Image(systemName: "bell.fill").font(.system(size: 7)).foregroundStyle(.orange)
                }
            }
            .frame(height: 24, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var selectedDayCard: some View {
        let items = entries(for: selectedKey)
        let date = Recurrence.date(forKey: selectedKey, calendar: calendar) ?? .now
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Format.day(date)).font(.headline)
                Spacer()
                Button("Открыть день") { onOpenDay(selectedKey) }
                    .font(.subheadline)
            }
            if items.isEmpty {
                Text("На этот день ничего не запланировано.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { entry in
                HStack(spacing: 8) {
                    if entry.isReminder {
                        Image(systemName: "bell.fill").font(.caption).foregroundStyle(.orange)
                    } else {
                        Circle().fill(Color(hex: entry.colorHex)).frame(width: 8, height: 8)
                    }
                    Text(entry.start.map(Format.time) ?? "весь день")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text(entry.title).font(.subheadline)
                    Spacer()
                    if entry.id.hasPrefix("rule-") {
                        Image(systemName: "calendar.badge.clock").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 8) {
                Button {
                    sheet = DaySheet(kind: .newBlock(start: nextStart()))
                } label: {
                    Label("Блок плана", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    sheet = DaySheet(kind: .reminder(nil))
                } label: {
                    Label("Напоминание", systemImage: "bell.badge")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    /// Новый блок: после последнего блока дня или в 9:00.
    private func nextStart() -> Date {
        let clock = DayClock.app
        if let last = days.first(where: { $0.key == selectedKey })?.activeBlocks.map(\.end).max(),
           let window = clock.window(forKey: selectedKey), last < window.end {
            return last
        }
        return clock.resolve(hour: 9, minute: 0, inDay: selectedKey) ?? .now
    }
}
