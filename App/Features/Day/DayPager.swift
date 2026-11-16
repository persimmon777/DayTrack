import DayTrackCore
import SwiftData
import SwiftUI

/// Обёртка вкладок «План», «Факт» и «Аналитика»: переключение дней стрелками
/// и выбор даты. Выбранный день общий для всех трёх вкладок.
struct DayPager<Content: View>: View {
    @Binding var dayKey: Int
    let content: (Int) -> Content

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var isPickingDate = false
    @State private var pickedDate = Date.now

    private let clock = DayClock.app

    init(dayKey: Binding<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        _dayKey = dayKey
        self.content = content
    }

    private var todayKey: Int { clock.key(for: .now) }

    private var title: String {
        guard let date = clock.calendarDate(forKey: dayKey) else { return "День" }
        let formatted = Format.day(date)
        switch dayKey {
        case todayKey: return "Сегодня, \(formatted)"
        case clock.key(byAdding: -1, to: todayKey): return "Вчера, \(formatted)"
        case clock.key(byAdding: 1, to: todayKey): return "Завтра, \(formatted)"
        default: return formatted
        }
    }

    var body: some View {
        NavigationStack {
            content(dayKey)
                .id(dayKey)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dayKey = clock.key(byAdding: -1, to: dayKey)
                        } label: {
                            Label("Предыдущий день", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Button {
                            pickedDate = clock.calendarDate(forKey: dayKey) ?? .now
                            isPickingDate = true
                        } label: {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if dayKey != todayKey {
                            Button("Сегодня") { dayKey = todayKey }
                        }
                        Button {
                            dayKey = clock.key(byAdding: 1, to: dayKey)
                        } label: {
                            Label("Следующий день", systemImage: "chevron.right")
                        }
                    }
                }
        }
        .sheet(isPresented: $isPickingDate) {
            datePicker
        }
        .onAppear(perform: autoLock)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { autoLock() }
        }
        .onChange(of: dayKey) { _, _ in
            autoLock()
        }
    }

    private var datePicker: some View {
        NavigationStack {
            DatePicker("День", selection: $pickedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .navigationTitle("Выбор дня")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { isPickingDate = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Открыть") {
                            // Полдень выбранной даты заведомо попадает в нужный день.
                            let noon = clock.calendar.startOfDay(for: pickedDate).addingTimeInterval(12 * 3600)
                            dayKey = clock.key(for: noon)
                            isPickingDate = false
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    /// План фиксируется сам, когда день уже начался.
    private func autoLock() {
        let store = DayStore(context: context)
        store.autoLockIfNeeded(dayKey: todayKey)
        if dayKey < todayKey {
            store.autoLockIfNeeded(dayKey: dayKey)
        }
    }
}

/// Круглая кнопка «+» в правом нижнем углу, под большой палец.
struct FloatingAddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .accessibilityLabel(label)
        .padding(20)
    }
}

/// Круглая кнопка «+», открывающая меню действий.
struct FloatingAddMenu<MenuContent: View>: View {
    let label: String
    @ViewBuilder let content: () -> MenuContent

    var body: some View {
        Menu(content: content) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .accessibilityLabel(label)
        .padding(20)
    }
}
