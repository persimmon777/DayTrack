import DayTrackCore
import SwiftData
import SwiftUI

/// Запуск отдыха с понятным концом.
struct RestStartSheet: View {
    let dayKey: Int

    @Environment(\.dismiss) private var dismiss
    @Query private var days: [Day]

    @State private var minutes = 15
    @State private var returnTo = ""
    @State private var loaded = false

    private let options = [5, 10, 15, 20, 30, 45, 60]

    init(dayKey: Int) {
        self.dayKey = dayKey
        _days = Query(filter: #Predicate<Day> { $0.key == dayKey })
    }

    /// Ближайший блок плана после окончания отдыха.
    private var nextBlockTitle: String {
        let end = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        return (days.first?.activeBlocks ?? [])
            .filter { $0.end > end && $0.category?.kind != .rest && $0.category?.kind != .sleep }
            .min { $0.start < $1.start }?.title ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Длительность", selection: $minutes) {
                        ForEach(options, id: \.self) { Text(DurationText.short(minutes: $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                } footer: {
                    Text("Отдых с понятным концом проще начать без чувства вины и проще закончить. Таймер будет виден на экране блокировки.")
                }
                Section("К чему вернусь") {
                    TextField("Например: курсовая", text: $returnTo)
                }
            }
            .navigationTitle("Отдых")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Начать") {
                        let minutes = minutes
                        let returnTo = returnTo.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task { await RestTimer.start(minutes: minutes, returnTo: returnTo) }
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                returnTo = nextBlockTitle
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Полоса идущего отдыха с кнопкой «Я вернулся».
struct RestBanner: View {
    @Environment(\.modelContext) private var context

    @AppStorage(RestTimerKeys.endsAt) private var endsAt: Double = 0
    @AppStorage(RestTimerKeys.startedAt) private var startedAt: Double = 0
    @AppStorage(RestTimerKeys.returnTo) private var returnTo: String = ""

    @State private var message: String?

    var body: some View {
        Group {
            if endsAt > 0 {
                content
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Понятно", role: .cancel) {}
        }
    }

    private var content: some View {
        let end = Date(timeIntervalSince1970: endsAt)
        let start = Date(timeIntervalSince1970: startedAt)
        return TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let overdue = timeline.date > end
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3)
                    .foregroundStyle(overdue ? .orange : .green)
                VStack(alignment: .leading, spacing: 2) {
                    if overdue {
                        Text("Отдых закончился \(DurationText.short(minutes: Int(timeline.date.timeIntervalSince(end) / 60))) назад")
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text("Отдых · осталось \(Text(timerInterval: min(timeline.date, end)...end, countsDown: true))")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    Text(returnTo.isEmpty ? "С \(Format.time(start)) до \(Format.time(end))" : "Потом: \(returnTo)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Menu {
                    Button("Отменить без записи", role: .destructive) {
                        Task { await RestTimer.cancel() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                }
                Button("Я вернулся") {
                    Task {
                        guard let result = await RestTimer.finish(context: context) else { return }
                        if result.actual > result.planned + 5 {
                            message = "Отдых занял \(DurationText.short(minutes: result.actual)) вместо \(DurationText.short(minutes: result.planned)). Записал как есть: честные данные помогут планировать отдых реалистичнее."
                        } else {
                            message = "Отдых записан в факт: \(DurationText.short(minutes: result.actual))."
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
            .background((overdue ? Color.orange : Color.green).opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
