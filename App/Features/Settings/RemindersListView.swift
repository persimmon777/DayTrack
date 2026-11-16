import DayTrackCore
import SwiftData
import SwiftUI

/// Все напоминания: повторяющиеся (дни рождения и т. п.) и предстоящие разовые.
struct RemindersListView: View {
    private struct EditorTarget: Identifiable {
        let id = UUID()
        let reminder: Reminder?
    }

    @Query(sort: \Reminder.firstDayKey) private var reminders: [Reminder]
    @State private var target: EditorTarget?

    private let calendar = Calendar.current
    private var todayKey: Int { Recurrence.keyOf(.now, calendar: calendar) }

    private var repeating: [Reminder] { reminders.filter { $0.repeatRule != .none } }
    private var upcoming: [Reminder] { reminders.filter { $0.repeatRule == .none && $0.firstDayKey >= todayKey } }
    private var past: [Reminder] {
        reminders.filter { $0.repeatRule == .none && $0.firstDayKey < todayKey }.reversed()
    }

    var body: some View {
        List {
            if reminders.isEmpty {
                Text("Напоминаний пока нет. Их можно добавить здесь или кнопкой «+» на вкладке «План».")
                    .foregroundStyle(.secondary)
            }
            section("Предстоящие", upcoming)
            section("Повторяющиеся", repeating)
            section("Прошедшие", past)
        }
        .navigationTitle("Напоминания")
        .toolbar {
            Button {
                target = EditorTarget(reminder: nil)
            } label: {
                Label("Добавить", systemImage: "plus")
            }
        }
        .sheet(item: $target) { item in
            ReminderEditorSheet(reminder: item.reminder, dayKey: todayKey)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [Reminder]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { reminder in
                    Button {
                        target = EditorTarget(reminder: reminder)
                    } label: {
                        ReminderRow(reminder: reminder, dateText: dateText(reminder))
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private func dateText(_ reminder: Reminder) -> String {
        let key: Int
        if reminder.repeatRule == .none {
            key = reminder.firstDayKey
        } else {
            let through = Recurrence.key(todayKey, addingDays: 400, calendar: calendar)
            key = Recurrence.occurrences(
                first: reminder.firstDayKey, rule: reminder.repeatRule,
                from: max(todayKey, reminder.firstDayKey), through: through, calendar: calendar
            ).first ?? reminder.firstDayKey
        }
        let date = Recurrence.date(forKey: key, calendar: calendar).map(Format.day) ?? ""
        return reminder.repeatRule == .none ? date : "ближайшее \(date)"
    }
}
