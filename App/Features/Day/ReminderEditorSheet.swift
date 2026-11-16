import DayTrackCore
import SwiftData
import SwiftUI

/// Форма напоминания или события.
struct ReminderEditorSheet: View {
    /// Существующее напоминание или `nil` для нового.
    let reminder: Reminder?
    /// День, на который создаётся новое напоминание.
    let dayKey: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var note: String
    @State private var date: Date
    @State private var isAllDay: Bool
    @State private var time: Date
    @State private var repeatRule: RepeatRule
    @State private var notify: Bool
    @State private var leadDays: Int
    @State private var repeatChosenByUser: Bool
    @State private var isConfirmingDelete = false
    @FocusState private var isTitleFocused: Bool

    private let calendar = Calendar.current

    init(reminder: Reminder?, dayKey: Int) {
        self.reminder = reminder
        self.dayKey = dayKey
        let calendar = Calendar.current
        let firstKey = reminder?.firstDayKey ?? dayKey
        let day = Recurrence.date(forKey: firstKey, calendar: calendar) ?? .now
        let minute = reminder?.minuteOfDay ?? 12 * 60
        _title = State(initialValue: reminder?.title ?? "")
        _note = State(initialValue: reminder?.note ?? "")
        _date = State(initialValue: day)
        _isAllDay = State(initialValue: reminder.map { $0.minuteOfDay == nil } ?? true)
        _time = State(initialValue: calendar.date(
            bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day
        ) ?? day)
        _repeatRule = State(initialValue: reminder?.repeatRule ?? .none)
        _notify = State(initialValue: reminder?.notify ?? true)
        _leadDays = State(initialValue: reminder?.leadDays ?? 0)
        _repeatChosenByUser = State(initialValue: reminder != nil)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Например: день рождения Маши, врач", text: $title)
                        .focused($isTitleFocused)
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                    Toggle("Весь день", isOn: $isAllDay)
                    if !isAllDay {
                        DatePicker("Время", selection: $time, displayedComponents: .hourAndMinute)
                    }
                    Picker("Повтор", selection: Binding(
                        get: { repeatRule },
                        set: { repeatRule = $0; repeatChosenByUser = true }
                    )) {
                        ForEach(RepeatRule.allCases, id: \.self) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }
                }

                Section {
                    Toggle("Уведомление", isOn: $notify)
                    if notify {
                        Picker("Когда", selection: $leadDays) {
                            Text("В тот же день").tag(0)
                            Text("За 1 день").tag(1)
                            Text("За 3 дня").tag(3)
                            Text("За неделю").tag(7)
                        }
                    }
                } footer: {
                    if notify {
                        Text(leadDays == 0 && !isAllDay
                             ? "Уведомление придёт в указанное время."
                             : "Уведомление придёт в 9:00.")
                    }
                }

                Section("Заметка") {
                    TextField("Необязательно", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if reminder != nil {
                    Section {
                        Button("Удалить", role: .destructive) { isConfirmingDelete = true }
                    }
                }
            }
            .navigationTitle(reminder == nil ? "Напоминание" : "Изменить")
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
                // День рождения почти всегда повторяется каждый год.
                guard !repeatChosenByUser else { return }
                let yearly = KeywordMatcher.score(title: newTitle, keywords: ["день рожд", "др", "годовщин"]) != nil
                repeatRule = yearly ? .yearly : .none
            }
            .confirmationDialog("Удалить напоминание?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive, action: delete)
            }
            .onAppear {
                if reminder == nil { isTitleFocused = true }
            }
        }
    }

    private func save() {
        let target = reminder ?? {
            let new = Reminder(title: trimmedTitle, firstDayKey: dayKey)
            context.insert(new)
            return new
        }()
        target.title = trimmedTitle
        target.note = note
        target.firstDayKey = Recurrence.keyOf(date, calendar: calendar)
        if isAllDay {
            target.minuteOfDay = nil
        } else {
            let parts = calendar.dateComponents([.hour, .minute], from: time)
            target.minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
        target.repeatRule = repeatRule
        target.notify = notify
        target.leadDays = notify ? leadDays : 0
        try? context.save()

        let context = self.context
        let wantsNotifications = notify
        Task { @MainActor in
            if wantsNotifications { await ReminderScheduler.requestPermission() }
            await ReminderScheduler.reschedule(context: context)
        }
        dismiss()
    }

    private func delete() {
        guard let reminder else { return }
        let context = self.context
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            context.delete(reminder)
            try? context.save()
            await ReminderScheduler.reschedule(context: context)
        }
    }
}

/// Строка напоминания в списках.
struct ReminderRow: View {
    let reminder: Reminder
    /// Подпись даты, если строка показывается не в своём дне.
    var dateText: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: reminder.minuteOfDay == nil ? "bell.badge" : "clock.badge")
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title)
                    .font(.subheadline)
                Text([dateText, reminder.timeText].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if reminder.repeatRule != .none {
                Image(systemName: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !reminder.notify {
                Image(systemName: "bell.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
