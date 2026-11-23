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
                        let label = returnTo.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task { await RestTimer.start(mode: .rest, minutes: minutes, label: label) }
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

/// «Только начать»: несколько минут на большое дело.
struct FocusStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.sortOrder) private var projects: [Project]

    @State private var projectID: UUID?
    @State private var step = ""
    @State private var minutes: Int

    private let options = [2, 5, 10, 15, 25, 45]

    init(projectID: UUID? = nil, minutes: Int = 5) {
        _projectID = State(initialValue: projectID)
        _minutes = State(initialValue: minutes)
    }

    private var project: Project? { projects.first { $0.uuid == projectID } }

    var body: some View {
        NavigationStack {
            Form {
                if !projects.isEmpty {
                    Section {
                        Picker("Дело", selection: $projectID) {
                            Text("Другое").tag(UUID?.none)
                            ForEach(projects) { Text($0.title).tag(UUID?.some($0.uuid)) }
                        }
                    }
                }
                Section {
                    TextField("Что именно сделаю", text: $step, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Один маленький шаг")
                } footer: {
                    Text("Чем конкретнее, тем легче начать: не «учить Swift», а «открыть урок 4 и прочитать первый раздел».")
                }
                Section {
                    Picker("Минут", selection: $minutes) {
                        ForEach(options, id: \.self) { Text("\($0) мин").tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Договор с собой: только эти минуты. Потом можно честно остановиться. Обычно трудно лишь начать — дальше идёт легче.")
                }
            }
            .navigationTitle("Только начать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Поехали") {
                        let minutes = minutes
                        let label = step.trimmingCharacters(in: .whitespacesAndNewlines)
                        let id = projectID
                        Task { await RestTimer.start(mode: .focus, minutes: minutes, label: label, projectUUID: id) }
                        dismiss()
                    }
                }
            }
            .onAppear { fillStep() }
            .onChange(of: projectID) { _, _ in fillStep() }
        }
        .presentationDetents([.medium, .large])
    }

    private func fillStep() {
        step = project?.nextStep?.title ?? ""
    }
}

/// Игры по таймеру с недельным бюджетом.
struct GameStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var minutes = 45

    private let options = [15, 30, 45, 60, 90, 120]

    var body: some View {
        let stats = GameSettings.weekStats(context: context)
        let remaining = GameSettings.remaining(context: context)
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Сыграно за неделю", value: DurationText.short(minutes: stats.played))
                    if GameSettings.earnByStudy {
                        LabeledContent("Заработано учёбой", value: DurationText.short(minutes: min(stats.studied, GameSettings.weeklyBudgetMinutes)))
                    } else {
                        LabeledContent("Бюджет на неделю", value: DurationText.short(minutes: GameSettings.weeklyBudgetMinutes))
                    }
                    LabeledContent("Осталось", value: DurationText.short(minutes: remaining))
                        .foregroundStyle(remaining == 0 ? .orange : .primary)
                }
                Section {
                    Picker("Сколько играю", selection: $minutes) {
                        ForEach(options, id: \.self) { Text(DurationText.short(minutes: $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                } footer: {
                    Text(minutes > remaining
                         ? "Это больше, чем осталось в бюджете. Можно и так — запишется честно, но подумай о меньшем времени."
                         : "Игры — нормальный отдых, если у них есть конец. Таймер напомнит, когда пора выходить, и ещё раз, если затянется.")
                }
            }
            .navigationTitle("Игра по таймеру")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Начать") {
                        let minutes = minutes
                        Task { await RestTimer.start(mode: .game, minutes: minutes, label: "") }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Полоса идущей сессии: отдых, фокус или игра.
struct RestBanner: View {
    @Environment(\.modelContext) private var context

    @AppStorage(RestTimerKeys.endsAt) private var endsAt: Double = 0
    @AppStorage(RestTimerKeys.startedAt) private var startedAt: Double = 0
    @AppStorage(RestTimerKeys.returnTo) private var label: String = ""
    @AppStorage(RestTimerKeys.mode) private var modeRaw: String = SessionMode.rest.rawValue

    @State private var message: String?
    @State private var finishedFocus: SessionResult?

    private var mode: SessionMode { SessionMode(rawValue: modeRaw) ?? .rest }

    var body: some View {
        Group {
            if endsAt > 0 {
                content
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Понятно", role: .cancel) {}
        }
        .alert(
            "Ты начал — это главное",
            isPresented: Binding(get: { finishedFocus != nil }, set: { if !$0 { finishedFocus = nil } }),
            presenting: finishedFocus
        ) { result in
            if result.projectUUID != nil, !result.stepTitle.isEmpty {
                Button("Шаг сделан") { markStepDone(result) }
            }
            Button("Ещё не закончил", role: .cancel) {}
        } message: { result in
            Text("\(DurationText.short(minutes: result.actual)) на деле записаны в факт. Завтра продолжишь с того же места — главное не пропускать два дня подряд.")
        }
    }

    private var tint: Color {
        switch mode {
        case .rest: return .green
        case .focus: return .accentColor
        case .game: return .pink
        }
    }

    private var content: some View {
        let end = Date(timeIntervalSince1970: endsAt)
        let start = Date(timeIntervalSince1970: startedAt)
        return TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let overdue = timeline.date > end
            HStack(spacing: 12) {
                Image(systemName: mode.symbol)
                    .font(.title3)
                    .foregroundStyle(overdue && mode != .focus ? .orange : tint)
                VStack(alignment: .leading, spacing: 2) {
                    if overdue {
                        Text(overdueText(minutes: Int(timeline.date.timeIntervalSince(end) / 60)))
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text("\(mode.title) · осталось \(Text(timerInterval: min(timeline.date, end)...end, countsDown: true))")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    Text(subtitle(start: start, end: end))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Menu {
                    Button("Отменить без записи", role: .destructive) {
                        Task { await RestTimer.cancel() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                }
                Button(mode.finishTitle, action: finish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(12)
            .background((overdue && mode != .focus ? Color.orange : tint).opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func overdueText(minutes: Int) -> String {
        switch mode {
        case .rest: return "Отдых закончился \(DurationText.short(minutes: max(minutes, 1))) назад"
        case .focus: return "Сверх плана \(DurationText.short(minutes: max(minutes, 1))) — отлично идёт"
        case .game: return "Игра идёт сверх плана: \(DurationText.short(minutes: max(minutes, 1)))"
        }
    }

    private func subtitle(start: Date, end: Date) -> String {
        switch mode {
        case .rest: return label.isEmpty ? "С \(Format.time(start)) до \(Format.time(end))" : "Потом: \(label)"
        case .focus: return label.isEmpty ? "Только эти минуты, потом можно остановиться" : label
        case .game: return "До \(Format.time(end)). Сохранись заранее"
        }
    }

    private func finish() {
        Task {
            guard let result = await RestTimer.finish(context: context) else { return }
            switch result.mode {
            case .focus:
                finishedFocus = result
            case .rest:
                message = result.actual > result.planned + 5
                    ? "Отдых занял \(DurationText.short(minutes: result.actual)) вместо \(DurationText.short(minutes: result.planned)). Записал как есть: честные данные помогут планировать отдых реалистичнее."
                    : "Отдых записан в факт: \(DurationText.short(minutes: result.actual))."
            case .game:
                let remaining = GameSettings.remaining(context: context)
                message = result.actual > result.planned + 5
                    ? "Игра заняла \(DurationText.short(minutes: result.actual)) вместо \(DurationText.short(minutes: result.planned)). Это не провал, а данные: в следующий раз сохранись за 5 минут до конца таймера. На неделе осталось \(DurationText.short(minutes: remaining))."
                    : "Ты остановился вовремя — это настоящий навык. На неделе осталось \(DurationText.short(minutes: remaining)) игр."
            }
        }
    }

    private func markStepDone(_ result: SessionResult) {
        guard let id = result.projectUUID,
              let project = (try? context.fetch(FetchDescriptor<Project>()))?.first(where: { $0.uuid == id }) else { return }
        var steps = project.steps
        if let index = steps.firstIndex(where: { !$0.isDone && $0.title == result.stepTitle }) {
            steps[index].isDone = true
            project.steps = steps
            try? context.save()
        }
    }
}
