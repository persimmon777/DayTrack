import DayTrackCore
import SwiftData
import SwiftUI

/// Быстрая отметка энергии и настроения.
struct EnergySheet: View {
    let dayKey: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var energy = 3
    @State private var mood = 3
    @State private var time: Date

    private let clock = DayClock.app

    init(dayKey: Int) {
        self.dayKey = dayKey
        let clock = DayClock.app
        let isToday = clock.key(for: .now) == dayKey
        _time = State(initialValue: isToday ? .now : (clock.resolve(hour: 12, minute: 0, inDay: dayKey) ?? .now))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Энергия") {
                    ScalePicker(value: $energy, low: "нет сил", high: "полон сил")
                }
                Section("Настроение") {
                    ScalePicker(value: $mood, low: "плохое", high: "отличное")
                }
                Section {
                    DatePicker("Время", selection: $time, displayedComponents: .hourAndMinute)
                } footer: {
                    Text("Отмечай пару раз в день. Через две недели станет видно, в какие часы у тебя больше всего сил, и сложное можно будет ставить на них.")
                }
            }
            .navigationTitle("Как ты сейчас")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let at = clock.resolve(timeOf: time, inDay: dayKey) ?? time
                        context.insert(EnergyMark(at: at, dayKey: dayKey, energy: energy, mood: mood))
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Пять кнопок от 1 до 5 с подписями краёв.
struct ScalePicker: View {
    @Binding var value: Int
    let low: String
    let high: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        value = level
                    } label: {
                        Text("\(level)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                level == value ? Color.accentColor : Color(.tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .foregroundStyle(level == value ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
