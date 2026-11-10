import DayTrackCore
import SwiftData
import SwiftUI

/// Вкладка «Сегодня»: выбор дня и его экран.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var dayKey = DayClock.app.key(for: .now)
    @State private var isPickingDate = false
    @State private var pickedDate = Date.now

    private let clock = DayClock.app

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
            DayView(dayKey: dayKey)
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
