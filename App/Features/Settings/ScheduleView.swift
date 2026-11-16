import DayTrackCore
import SwiftData
import SwiftUI

/// Расписание по дням недели.
struct ScheduleView: View {
    private struct EditorTarget: Identifiable {
        let id = UUID()
        let rule: ScheduleRule?
        let weekday: Int
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \ScheduleRule.startMinute) private var rules: [ScheduleRule]
    @State private var target: EditorTarget?
    @State private var firstWeekDate: Date

    private let calendar = Calendar.current
    /// Дни недели по порядку с понедельника.
    static let weekdays: [(id: Int, title: String)] = [
        (2, "Понедельник"), (3, "Вторник"), (4, "Среда"), (5, "Четверг"),
        (6, "Пятница"), (7, "Суббота"), (1, "Воскресенье"),
    ]

    init() {
        _firstWeekDate = State(initialValue: Recurrence.date(
            forKey: ScheduleSettings.firstWeekKey, calendar: .current
        ) ?? .now)
    }

    private var currentWeek: Int? {
        WeeklySchedule.weekNumber(
            of: DayClock.app.key(for: .now),
            firstWeekKey: ScheduleSettings.firstWeekKey,
            calendar: calendar
        )
    }

    var body: some View {
        List {
            Section {
                DatePicker("Начало учёбы", selection: $firstWeekDate, displayedComponents: .date)
                if let week = currentWeek, week > 0 {
                    LabeledContent("Сейчас", value: "\(week)-я неделя, \(week % 2 == 1 ? "нечётная" : "чётная")")
                }
            } footer: {
                Text("От этой даты считаются чётные и нечётные недели: неделя с ней — первая, нечётная. Занятия из расписания сами появляются в плане сегодняшнего и будущих дней.")
            }

            ForEach(Self.weekdays, id: \.id) { weekday in
                Section(weekday.title) {
                    ForEach(rules.filter { $0.weekday == weekday.id }) { rule in
                        Button {
                            target = EditorTarget(rule: rule, weekday: weekday.id)
                        } label: {
                            row(rule)
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        let items = rules.filter { $0.weekday == weekday.id }
                        for index in offsets { context.delete(items[index]) }
                        try? context.save()
                    }
                    Button {
                        target = EditorTarget(rule: nil, weekday: weekday.id)
                    } label: {
                        Label("Добавить занятие", systemImage: "plus")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Расписание")
        .onChange(of: firstWeekDate) { _, date in
            ScheduleSettings.firstWeekKey = Recurrence.keyOf(date, calendar: calendar)
        }
        .sheet(item: $target) { item in
            ScheduleRuleEditor(rule: item.rule, weekday: item.weekday)
        }
    }

    private func row(_ rule: ScheduleRule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.title)
                    .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                if rule.parity != .every || rule.validUntilKey != nil {
                    Text([rule.parity == .every ? nil : rule.parity.title,
                          rule.validUntilKey.map { "до \(Self.dateText($0))" }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(Self.time(rule.startMinute))–\(Self.time(rule.endMinute))")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    static func time(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60 % 24, minute % 60)
    }

    static func dateText(_ key: Int) -> String {
        Recurrence.date(forKey: key, calendar: .current).map(Format.day) ?? ""
    }
}

/// Форма занятия расписания.
struct ScheduleRuleEditor: View {
    let rule: ScheduleRule?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ActivityCategory.sortOrder) private var categories: [ActivityCategory]

    @State private var title: String
    @State private var categoryID: UUID?
    @State private var categoryChosenByUser: Bool
    @State private var weekday: Int
    @State private var start: Date
    @State private var end: Date
    @State private var parity: WeekParity
    @State private var hasUntil: Bool
    @State private var until: Date
    @State private var isEnabled: Bool

    private let calendar = Calendar.current

    init(rule: ScheduleRule?, weekday: Int) {
        self.rule = rule
        let calendar = Calendar.current
        func date(_ minute: Int) -> Date {
            calendar.date(bySettingHour: minute / 60 % 24, minute: minute % 60, second: 0, of: .now) ?? .now
        }
        _title = State(initialValue: rule?.title ?? "")
        _categoryID = State(initialValue: rule?.categoryUUID)
        _categoryChosenByUser = State(initialValue: rule?.categoryUUID != nil)
        _weekday = State(initialValue: rule?.weekday ?? weekday)
        _start = State(initialValue: date(rule?.startMinute ?? 9 * 60))
        _end = State(initialValue: date(rule?.endMinute ?? 10 * 60 + 30))
        _parity = State(initialValue: rule?.parity ?? .every)
        _hasUntil = State(initialValue: rule?.validUntilKey != nil)
        _until = State(initialValue: rule?.validUntilKey.flatMap { Recurrence.date(forKey: $0, calendar: calendar) }
            ?? calendar.date(byAdding: .month, value: 4, to: .now) ?? .now)
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func minute(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Например: Матанализ, лекция", text: $title)
                    CategoryPicker(categories: categories, selection: Binding(
                        get: { categoryID },
                        set: { categoryID = $0; categoryChosenByUser = true }
                    ))
                }
                Section {
                    Picker("День недели", selection: $weekday) {
                        ForEach(ScheduleView.weekdays, id: \.id) { Text($0.title).tag($0.id) }
                    }
                    DatePicker("Начало", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Конец", selection: $end, displayedComponents: .hourAndMinute)
                    Picker("Недели", selection: $parity) {
                        ForEach(WeekParity.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    Toggle("До определённой даты", isOn: $hasUntil)
                    if hasUntil {
                        DatePicker("Последний день", selection: $until, displayedComponents: .date)
                    }
                    Toggle("Действует", isOn: $isEnabled)
                } footer: {
                    Text("Изменения касаются дней, в которые расписание ещё не подставлено. В уже созданный план занятие можно добавить кнопкой «+» → «Подставить расписание».")
                }
            }
            .navigationTitle(rule == nil ? "Новое занятие" : "Занятие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .onChange(of: title) { _, newTitle in
                guard !categoryChosenByUser,
                      let match = CategoryKeywords.match(title: newTitle, in: categories) else { return }
                categoryID = match.uuid
            }
        }
    }

    private func save() {
        let target = rule ?? {
            let new = ScheduleRule(title: trimmedTitle, weekday: weekday)
            context.insert(new)
            return new
        }()
        target.title = trimmedTitle
        target.categoryUUID = categoryID
        target.weekday = weekday
        target.startMinute = minute(start)
        target.endMinute = minute(end)
        target.parity = parity
        target.validUntilKey = hasUntil ? Recurrence.keyOf(until, calendar: calendar) : nil
        target.isEnabled = isEnabled
        try? context.save()
        dismiss()
    }
}
