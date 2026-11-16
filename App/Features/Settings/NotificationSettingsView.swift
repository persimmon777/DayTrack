import SwiftData
import SwiftUI
import UserNotifications

/// Настройки уведомлений.
struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var context

    @State private var morningOn = NotificationSettings.morningOn
    @State private var morning = Self.date(NotificationSettings.morningMinute)
    @State private var eveningOn = NotificationSettings.eveningOn
    @State private var evening = Self.date(NotificationSettings.eveningMinute)
    @State private var factOn = NotificationSettings.factOn
    @State private var fact1 = Self.date(NotificationSettings.factMinutes.first ?? 13 * 60)
    @State private var fact2 = Self.date(NotificationSettings.factMinutes.dropFirst().first ?? 18 * 60)
    @State private var breakOn = NotificationSettings.breakOn
    @State private var breakInterval = NotificationSettings.breakInterval
    @State private var status = ""

    var body: some View {
        Form {
            if !status.isEmpty {
                Section {
                    Text(status).foregroundStyle(.orange)
                }
            }
            Section {
                Toggle("Утром: проверить план", isOn: $morningOn)
                if morningOn { DatePicker("Время", selection: $morning, displayedComponents: .hourAndMinute) }
                Toggle("Вечером: подвести итоги", isOn: $eveningOn)
                if eveningOn { DatePicker("Время", selection: $evening, displayedComponents: .hourAndMinute) }
            }
            Section {
                Toggle("Напоминать внести факт", isOn: $factOn)
                if factOn {
                    DatePicker("Первое", selection: $fact1, displayedComponents: .hourAndMinute)
                    DatePicker("Второе", selection: $fact2, displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text("Напоминание не придёт, если факт уже внесён почти до этого времени.")
            }
            Section {
                Toggle("Напоминать о перерыве", isOn: $breakOn)
                if breakOn {
                    Picker("После учёбы без паузы", selection: $breakInterval) {
                        Text("50 минут").tag(50)
                        Text("1,5 часа").tag(90)
                        Text("2 часа").tag(120)
                    }
                }
            } footer: {
                Text("Срабатывает по плану: если блоки учёбы идут подряд дольше выбранного времени. Короткие перерывы снижают усталость; конкретный интервал — это удобное значение, а не научная норма, выбирай под себя.")
            }
        }
        .navigationTitle("Уведомления")
        .task { await checkPermission() }
        .onDisappear(perform: save)
    }

    private func save() {
        NotificationSettings.morningOn = morningOn
        NotificationSettings.morningMinute = Self.minute(morning)
        NotificationSettings.eveningOn = eveningOn
        NotificationSettings.eveningMinute = Self.minute(evening)
        NotificationSettings.factOn = factOn
        NotificationSettings.factMinutes = [Self.minute(fact1), Self.minute(fact2)]
        NotificationSettings.breakOn = breakOn
        NotificationSettings.breakInterval = breakInterval
        let context = self.context
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await DailyNotifications.reschedule(context: context)
        }
    }

    private func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .denied {
            status = "Уведомления запрещены. Разреши их: «Настройки» iPhone → DayTrack → «Уведомления»."
        } else if settings.authorizationStatus == .notDetermined {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    static func date(_ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
    }

    static func minute(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

/// Цель баланса на день.
struct BalanceTargetView: View {
    @Environment(\.modelContext) private var context

    @State private var study = Double(BalanceTarget.studyMinutes) / 60
    @State private var rest = Double(BalanceTarget.restMinutes) / 60
    @State private var sleep = Double(BalanceTarget.sleepMinutes) / 60

    var body: some View {
        Form {
            Section {
                stepper("Учёба", value: $study, range: 0.5...14)
                stepper("Отдых", value: $rest, range: 0.5...10)
                stepper("Сон", value: $sleep, range: 5...11)
            } footer: {
                Text("Цель на один день. Виджет показывает факт против цели за сегодня или за прошедшие дни недели. Взрослым рекомендуют спать не меньше 7 часов.")
            }
        }
        .navigationTitle("Цель баланса")
        .onDisappear {
            BalanceTarget.studyMinutes = Int(study * 60)
            BalanceTarget.restMinutes = Int(rest * 60)
            BalanceTarget.sleepMinutes = Int(sleep * 60)
            WidgetSync.refresh(context: context)
        }
    }

    private func stepper(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 0.5) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.1f ч", value.wrappedValue).replacingOccurrences(of: ".", with: ","))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
