import DayTrackCore
import SwiftData
import SwiftUI

/// Карточка большого дела: сколько дней без движения и следующий шаг.
struct ProjectRow: View {
    let project: Project
    let onStart: () -> Void

    var body: some View {
        let idle = project.daysIdle()
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.title).font(.body.weight(.medium))
                Spacer()
                if project.workedToday {
                    Label("сегодня было", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if idle >= 2 {
                    Text("\(idle) дн. без движения")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2), in: Capsule())
                }
            }
            if let step = project.nextStep {
                Text("Следующий шаг: \(step.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Шаги не заданы — разбей дело на маленькие части")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            let steps = project.steps
            if !steps.isEmpty {
                ProgressView(value: Double(steps.filter(\.isDone).count), total: Double(steps.count))
            }
            Button(action: onStart) {
                Label("\(project.minimumMinutes) минут сейчас", systemImage: "play.fill")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

/// Форма большого дела с шагами.
struct ProjectEditorSheet: View {
    let project: Project?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ActivityCategory.sortOrder) private var categories: [ActivityCategory]

    @State private var title: String
    @State private var why: String
    @State private var categoryID: UUID?
    @State private var minimum: Int
    @State private var ifThen: String
    @State private var steps: [ProjectStep]
    @State private var newStep = ""
    @State private var newStepMinutes = 15
    @State private var nudgeOn: Bool
    @State private var nudgeTime: Date
    @State private var isConfirmingDelete = false

    init(project: Project?) {
        self.project = project
        _title = State(initialValue: project?.title ?? "")
        _why = State(initialValue: project?.why ?? "")
        _categoryID = State(initialValue: project?.categoryUUID)
        _minimum = State(initialValue: project?.minimumMinutes ?? 5)
        _ifThen = State(initialValue: project?.ifThen ?? "")
        _steps = State(initialValue: project?.steps ?? [])
        _nudgeOn = State(initialValue: project?.nudgeOn ?? true)
        _nudgeTime = State(initialValue: NotificationSettingsView.date(project?.nudgeMinute ?? 19 * 60))
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Например: выучить Swift", text: $title)
                    TextField("Зачем это мне", text: $why, axis: .vertical).lineLimit(1...3)
                    CategoryPicker(categories: categories, selection: $categoryID)
                }

                Section {
                    ForEach($steps) { $step in
                        HStack {
                            Button {
                                step.isDone.toggle()
                            } label: {
                                Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(step.isDone ? Color.green : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            TextField("Шаг", text: $step.title)
                                .strikethrough(step.isDone)
                            Text("\(step.minutes) мин")
                                .font(.caption)
                                .foregroundStyle(step.minutes > 25 ? .orange : .secondary)
                        }
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }

                    HStack {
                        TextField("Новый шаг", text: $newStep)
                            .onSubmit(addStep)
                        Picker("", selection: $newStepMinutes) {
                            ForEach([5, 10, 15, 25], id: \.self) { Text("\($0) мин").tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    if steps.isEmpty {
                        Button("Подставить шаги для объёмного задания") { addStarterSteps() }
                    }
                } header: {
                    Text("Шаги")
                } footer: {
                    Text("Большое задание пугает, а пугающее мы избегаем. Разбей его на шаги по 5–25 минут. Первый шаг должен быть смешно маленьким: «открыть задание и прочитать условие».")
                }

                Section {
                    Stepper("Минимум: \(minimum) мин", value: $minimum, in: 2...30)
                    TextField("Если …, то открываю на \(minimum) минут", text: $ifThen, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Минимум и план «если — то»")
                } footer: {
                    Text("Минимум засчитывается как «не бросил». План «если — то» привязывает старт к ситуации: «Если поел после пар, то открываю курс на \(minimum) минут». Такие планы заметно повышают шанс начать.")
                }

                Section {
                    Toggle("Напоминать, если сегодня не занимался", isOn: $nudgeOn)
                    if nudgeOn {
                        DatePicker("Время", selection: $nudgeTime, displayedComponents: .hourAndMinute)
                    }
                }

                if project != nil {
                    Section {
                        Button(project?.isArchived == true ? "Вернуть из архива" : "Готово, убрать в архив") {
                            project?.isArchived.toggle()
                            try? context.save()
                            dismiss()
                        }
                        Button("Удалить", role: .destructive) { isConfirmingDelete = true }
                    }
                }
            }
            .navigationTitle(project == nil ? "Большое дело" : "Изменить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save).disabled(trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog("Удалить дело?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    if let project { context.delete(project) }
                    try? context.save()
                    dismiss()
                }
            }
        }
    }

    private func addStep() {
        let text = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        steps.append(ProjectStep(title: text, minutes: newStepMinutes))
        newStep = ""
    }

    private func addStarterSteps() {
        steps = [
            ProjectStep(title: "Открыть задание и прочитать условие", minutes: 5),
            ProjectStep(title: "Выписать, что непонятно, отдельными вопросами", minutes: 10),
            ProjectStep(title: "Найти разобранный пример похожей задачи", minutes: 15),
            ProjectStep(title: "Сделать самую простую часть, пусть криво", minutes: 25),
            ProjectStep(title: "Сделать следующую часть", minutes: 25),
        ]
    }

    private func save() {
        let target = project ?? {
            let new = Project(title: trimmedTitle)
            context.insert(new)
            return new
        }()
        target.title = trimmedTitle
        target.why = why
        target.categoryUUID = categoryID
        target.minimumMinutes = minimum
        target.ifThen = ifThen
        target.steps = steps
        target.nudgeOn = nudgeOn
        target.nudgeMinute = NotificationSettingsView.minute(nudgeTime)
        try? context.save()
        let modelContext = context
        Task { await DailyNotifications.reschedule(context: modelContext) }
        dismiss()
    }
}

/// Помощь, когда тянет сбежать от дела.
struct EscapeHelpSheet: View {
    var projectID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.sortOrder) private var projects: [Project]

    @State private var feeling: Feeling?
    @State private var question = ""
    @State private var selectedProject: UUID?
    @State private var isStartingRest = false
    @State private var isStartingGame = false

    enum Feeling: String, CaseIterable, Identifiable {
        case hard = "Слишком сложно"
        case unclear = "Непонятно, с чего начать"
        case boring = "Скучно"
        case scared = "Боюсь, что не получится"
        case tired = "Нет сил"
        case games = "Тянет поиграть"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .hard: return "mountain.2"
            case .unclear: return "questionmark.circle"
            case .boring: return "zzz"
            case .scared: return "exclamationmark.triangle"
            case .tired: return "battery.25"
            case .games: return "gamecontroller"
            }
        }
    }

    init(projectID: UUID? = nil) {
        self.projectID = projectID
        _selectedProject = State(initialValue: projectID)
    }

    private var project: Project? { projects.first { $0.uuid == selectedProject } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Желание сбежать — это не лень, а способ уйти от неприятного чувства. Назови его — так с ним легче справиться.")
                        .font(.subheadline)
                }
                if !projects.isEmpty {
                    Section {
                        Picker("От какого дела", selection: $selectedProject) {
                            Text("Не выбрано").tag(UUID?.none)
                            ForEach(projects) { Text($0.title).tag(UUID?.some($0.uuid)) }
                        }
                    }
                }
                Section("Что сейчас чувствуешь?") {
                    ForEach(Feeling.allCases) { item in
                        Button {
                            withAnimation { feeling = item }
                        } label: {
                            HStack {
                                Label(item.rawValue, systemImage: item.symbol)
                                Spacer()
                                if feeling == item { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
                if let feeling {
                    Section("Что можно сделать") { advice(for: feeling) }
                }
            }
            .navigationTitle("Хочу сбежать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .sheet(isPresented: $isStartingRest) { RestStartSheet(dayKey: DayClock.app.key(for: .now)) }
            .sheet(isPresented: $isStartingGame) { GameStartSheet() }
        }
    }

    private var stepTitle: String { project?.nextStep?.title ?? "" }

    @ViewBuilder
    private func advice(for feeling: Feeling) -> some View {
        switch feeling {
        case .hard:
            Text("Сделай дело меньше, а не себя сильнее. Возьми самый крошечный кусок и только 5 минут.")
            startButton("Начать на 5 минут", minutes: 5)
        case .unclear:
            Text("Запиши один вопрос, который мешает начать. Найти ответ на него и есть первый шаг.")
            TextField("Например: как устроен цикл for?", text: $question, axis: .vertical)
            startButton("Искать ответ 10 минут", minutes: 10, label: question.isEmpty ? stepTitle : "Найти ответ: \(question)")
        case .boring:
            Text("Скучное проще сделать коротким рывком с наградой: 15 минут дела, потом то, что нравится. Можно включить фоновую музыку.")
            startButton("15 минут, потом награда", minutes: 15)
        case .scared:
            Text("Первая попытка имеет право быть плохой. Задача сейчас — не сделать хорошо, а сделать черновик. Ты не обязан справиться сразу: никто не справляется.")
            startButton("Плохой черновик за 10 минут", minutes: 10)
        case .tired:
            Text("Если сил правда нет, честный отдых лучше, чем час прокрастинации с чувством вины. Отдохни по таймеру, а потом — 5 минут дела.")
            Button("Отдых по таймеру") { isStartingRest = true }
            startButton("Всё-таки 5 минут", minutes: 5)
        case .games:
            Text("Игры не враг — враг игры без конца. Сначала 25 минут дела, потом игра по таймеру: так игра становится наградой, а не побегом.")
            startButton("25 минут дела", minutes: 25)
            Button("Игра по таймеру") { isStartingGame = true }
        }
    }

    private func startButton(_ title: String, minutes: Int, label: String? = nil) -> some View {
        Button {
            let text = label ?? stepTitle
            let id = selectedProject
            Task { await RestTimer.start(mode: .focus, minutes: minutes, label: text, projectUUID: id) }
            dismiss()
        } label: {
            Label(title, systemImage: "play.fill")
        }
    }
}

/// Напоминание в плане о брошенных больших делах.
struct ProjectNudgeCard: View {
    let onStart: (Project) -> Void

    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.sortOrder) private var projects: [Project]

    private var stale: [Project] {
        projects.filter { !$0.workedToday && $0.daysIdle() >= 1 }
    }

    var body: some View {
        if let project = stale.first {
            let idle = project.daysIdle()
            VStack(alignment: .leading, spacing: 8) {
                Label(project.title, systemImage: "arrow.uturn.backward.circle")
                    .font(.subheadline.weight(.semibold))
                Text(idle >= 2
                     ? "\(idle) дн. без движения. Не нужно наверстывать — достаточно \(project.minimumMinutes) минут сегодня, чтобы цепочка снова началась."
                     : "Вчера не получилось — сегодня главное не пропустить второй день подряд. \(project.minimumMinutes) минут достаточно.")
                    .font(.footnote)
                if !project.ifThen.isEmpty {
                    Text("Твой план: \(project.ifThen)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    onStart(project)
                } label: {
                    Label("\(project.minimumMinutes) минут сейчас", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
