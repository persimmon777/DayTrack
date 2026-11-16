import DayTrackCore
import SwiftUI

/// Включение правил советчика и пороги.
struct AdvisorSettingsView: View {
    @State private var disabled = AdvisorPreferences.disabled
    @State private var load = AdvisorPreferences.loadLimitPercent
    @State private var buffer = AdvisorPreferences.bufferMinutes
    @State private var ceiling = Double(AdvisorPreferences.studyCeilingMinutes) / 60
    @State private var wake = NotificationSettingsView.date(UserProfile.wakeMinute)
    @State private var bed = NotificationSettingsView.date(UserProfile.bedMinute % (24 * 60))

    var body: some View {
        Form {
            Section {
                ForEach(AdviceRule.allCases, id: \.self) { rule in
                    Toggle(rule.title, isOn: Binding(
                        get: { !disabled.contains(rule) },
                        set: { if $0 { disabled.remove(rule) } else { disabled.insert(rule) } }
                    ))
                }
            } header: {
                Text("Правила")
            } footer: {
                Text("Подсказки появляются в плане дня. У каждой есть кнопка «Почему?»: там видно, исследование это или практический приём.")
            }

            Section("Пороги") {
                Stepper("Лимит загрузки: \(load)%", value: $load, in: 50...90, step: 5)
                Stepper("Резерв: \(DurationText.short(minutes: buffer))", value: $buffer, in: 15...120, step: 15)
                Stepper(value: $ceiling, in: 3...12, step: 0.5) {
                    Text("Потолок учёбы: \(String(format: "%.1f", ceiling).replacingOccurrences(of: ".", with: ",")) ч")
                }
            }

            Section {
                DatePicker("Подъём", selection: $wake, displayedComponents: .hourAndMinute)
                DatePicker("Отбой", selection: $bed, displayedComponents: .hourAndMinute)
            } footer: {
                Text("По времени подъёма и отбоя считается, какая доля дня занята планом.")
            }
        }
        .navigationTitle("Советчик")
        .onDisappear {
            AdvisorPreferences.disabled = disabled
            AdvisorPreferences.loadLimitPercent = load
            AdvisorPreferences.bufferMinutes = buffer
            AdvisorPreferences.studyCeilingMinutes = Int(ceiling * 60)
            UserProfile.wakeMinute = NotificationSettingsView.minute(wake)
            UserProfile.bedMinute = NotificationSettingsView.minute(bed)
        }
    }
}
