import DayTrackCore
import SwiftData
import SwiftUI
import UserNotifications

/// Первый запуск: режим дня, цель баланса, уведомления, как пользоваться.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @State private var wake = NotificationSettingsView.date(UserProfile.wakeMinute)
    @State private var bed = NotificationSettingsView.date(UserProfile.bedMinute % (24 * 60))
    @State private var study = Double(BalanceTarget.studyMinutes) / 60
    @State private var rest = Double(BalanceTarget.restMinutes) / 60
    @State private var sleep = Double(BalanceTarget.sleepMinutes) / 60
    @State private var notificationsAsked = false

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                welcome.tag(0)
                schedule.tag(1)
                notifications.tag(2)
                howTo.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .safeAreaInset(edge: .bottom) {
                Button(page == 3 ? "Начать" : "Дальше") {
                    if page == 3 { finish() } else { withAnimation { page += 1 } }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Пропустить", action: finish)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func pageLayout<Content: View>(_ symbol: String, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.title2.weight(.bold))
                content()
            }
            .padding(24)
            .padding(.bottom, 60)
        }
    }

    private var welcome: some View {
        pageLayout("calendar.day.timeline.left", "DayTrack: план и факт") {
            Text("Утром составляешь план, днём отмечаешь, что было на самом деле, вечером видишь разницу. Без оценок и упрёков: процент выполнения — это данные, по которым план становится реалистичнее.")
            Text("Приложение подсказывает, где добавить отдых, резерв и перерывы, и учится на твоей статистике: например, заметит, что на учёбу обычно уходит больше времени, чем ты закладываешь.")
                .foregroundStyle(.secondary)
        }
    }

    private var schedule: some View {
        pageLayout("bed.double", "Режим и цель") {
            DatePicker("Обычно встаю", selection: $wake, displayedComponents: .hourAndMinute)
            DatePicker("Обычно ложусь", selection: $bed, displayedComponents: .hourAndMinute)
            Divider()
            Text("Сколько в день хочется уделять:").font(.subheadline.weight(.semibold))
            stepper("Учёбе", $study, 0.5...14)
            stepper("Отдыху", $rest, 0.5...10)
            stepper("Сну", $sleep, 5...11)
            Text("Всё это можно поменять потом в настройках.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var notifications: some View {
        pageLayout("bell.badge", "Уведомления") {
            Text("Утром — заглянуть в план, вечером — подвести итоги, днём — отметить факт и вовремя сделать перерыв. Каждое отключается отдельно.")
            Button(notificationsAsked ? "Готово" : "Разрешить уведомления") {
                Task {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                    notificationsAsked = true
                }
            }
            .buttonStyle(.bordered)
            .disabled(notificationsAsked)
        }
    }

    private var howTo: some View {
        pageLayout("hand.tap", "Как пользоваться") {
            tip("list.bullet.clipboard", "План", "Кнопка «+» или нажатие на шкалу. Постоянные занятия — в «Настройки» → «Расписание».")
            tip("checkmark.circle", "Факт", "«+» добавляет запись с конца предыдущей. Обязательно только время.")
            tip("scope", "Фокусы", "Одна–три главные цели недели и месяца, к ним привязываются дела.")
            tip("chart.bar.xaxis", "Аналитика", "Графики, календарь и отчёт для нейросети.")
            tip("externaldrive.badge.timemachine", "Копии", "Включи автокопию в «Настройки» → «Резервные копии», чтобы данные не пропали.")
        }
    }

    private func tip(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).frame(width: 28).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func stepper(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
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

    private func finish() {
        UserProfile.wakeMinute = NotificationSettingsView.minute(wake)
        UserProfile.bedMinute = NotificationSettingsView.minute(bed)
        BalanceTarget.studyMinutes = Int(study * 60)
        BalanceTarget.restMinutes = Int(rest * 60)
        BalanceTarget.sleepMinutes = Int(sleep * 60)
        onFinish()
    }
}
