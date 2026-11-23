import DayTrackCore
import SwiftData
import SwiftUI

/// Вкладка «Фокусы»: фокусы выбранной недели и её месяца.
struct FocusView: View {
    @State private var anchorKey = DayClock.app.key(for: .now)

    private let calendar = Calendar.current

    private var weekRange: ClosedRange<Int> { Periods.range(.week, containing: anchorKey, calendar: calendar) }
    private var monthRange: ClosedRange<Int> { Periods.range(.month, containing: anchorKey, calendar: calendar) }

    var body: some View {
        NavigationStack {
            FocusPeriodList(weekRange: weekRange, monthRange: monthRange)
                .id(anchorKey)
                .navigationTitle("Фокусы")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            anchorKey = Periods.shift(anchorKey, kind: .week, by: -1, calendar: calendar)
                        } label: {
                            Label("Предыдущая неделя", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if !weekRange.contains(DayClock.app.key(for: .now)) {
                            Button("Сейчас") { anchorKey = DayClock.app.key(for: .now) }
                        }
                        Button {
                            anchorKey = Periods.shift(anchorKey, kind: .week, by: 1, calendar: calendar)
                        } label: {
                            Label("Следующая неделя", systemImage: "chevron.right")
                        }
                    }
                }
        }
    }
}

private struct FocusPeriodList: View {
    let weekRange: ClosedRange<Int>
    let monthRange: ClosedRange<Int>

    private struct EditorTarget: Identifiable {
        let id = UUID()
        let focus: Focus?
        let period: FocusPeriod
    }

    @Query(sort: \Focus.sortOrder) private var allFocuses: [Focus]
    @Query private var days: [Day]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @State private var target: EditorTarget?

    private struct ProjectTarget: Identifiable {
        let id = UUID()
        let project: Project?
    }

    @State private var projectTarget: ProjectTarget?
    @State private var focusProject: Project?
    @State private var isShowingEscape = false
    @State private var isShowingArchive = false

    init(weekRange: ClosedRange<Int>, monthRange: ClosedRange<Int>) {
        self.weekRange = weekRange
        self.monthRange = monthRange
        let from = min(weekRange.lowerBound, monthRange.lowerBound)
        let to = max(weekRange.upperBound, monthRange.upperBound)
        _days = Query(filter: #Predicate<Day> { $0.key >= from && $0.key <= to })
    }

    private var weekFocuses: [Focus] {
        allFocuses.filter { $0.period == .week && $0.periodStartKey == weekRange.lowerBound }
    }

    private var monthFocuses: [Focus] {
        allFocuses.filter { $0.period == .month && $0.periodStartKey == monthRange.lowerBound }
    }

    private var weekProgress: [UUID: FocusProgress] {
        FocusProgress.compute(focuses: weekFocuses, days: days.filter { weekRange.contains($0.key) })
    }

    private var monthProgress: [UUID: FocusProgress] {
        // В месячный фокус идут и его недельные шаги, поэтому учитываются все фокусы месяца.
        let related = allFocuses.filter { monthRange.contains($0.periodStartKey) || $0.periodStartKey == monthRange.lowerBound }
        return FocusProgress.compute(focuses: related, days: days.filter { monthRange.contains($0.key) })
    }

    var body: some View {
        List {
            projectsSection

            section(
                title: "Неделя \(rangeText(weekRange))",
                focuses: weekFocuses,
                progress: weekProgress,
                period: .week
            )
            section(
                title: monthTitle,
                focuses: monthFocuses,
                progress: monthProgress,
                period: .month
            )
            Section {
            } footer: {
                Text("Фокус — то главное, ради чего этот период. Привязывай к нему блоки плана, задачи и записи факта: время посчитается само. Лучше не больше трёх фокусов на период.")
            }
        }
        .sheet(item: $projectTarget) { item in
            ProjectEditorSheet(project: item.project)
        }
        .sheet(item: $focusProject) { project in
            FocusStartSheet(projectID: project.uuid, minutes: project.minimumMinutes)
        }
        .sheet(isPresented: $isShowingEscape) {
            EscapeHelpSheet()
        }
        .sheet(item: $target) { item in
            FocusEditorSheet(
                focus: item.focus,
                period: item.period,
                periodStartKey: item.period == .week ? weekRange.lowerBound : monthRange.lowerBound,
                activeCount: (item.period == .week ? weekFocuses : monthFocuses).filter { $0.status != .dropped }.count,
                monthFocuses: monthFocuses
            )
        }
    }

    private var projectsSection: some View {
        let active = projects.filter { !$0.isArchived }
        let archived = projects.filter(\.isArchived)
        return Section {
            ForEach(active) { project in
                ProjectRow(project: project) { focusProject = project }
                    .contentShape(Rectangle())
                    .onTapGesture { projectTarget = ProjectTarget(project: project) }
            }
            Button {
                projectTarget = ProjectTarget(project: nil)
            } label: {
                Label("Большое дело", systemImage: "plus")
            }
            Button {
                isShowingEscape = true
            } label: {
                Label("Хочу сбежать — помоги", systemImage: "lifepreserver")
            }
            if !archived.isEmpty {
                DisclosureGroup("Завершённые: \(archived.count)", isExpanded: $isShowingArchive) {
                    ForEach(archived) { project in
                        Text(project.title)
                            .foregroundStyle(.secondary)
                            .onTapGesture { projectTarget = ProjectTarget(project: project) }
                    }
                }
            }
        } header: {
            Text("Большие дела")
        } footer: {
            Text("Курс, проект или объёмное задание, которое легко забросить. Дело разбивается на шаги по 5–25 минут, а минимум в несколько минут в день не даёт цепочке оборваться.")
        }
    }

    @ViewBuilder
    private func section(title: String, focuses: [Focus], progress: [UUID: FocusProgress], period: FocusPeriod) -> some View {
        Section(title) {
            ForEach(focuses) { focus in
                Button {
                    target = EditorTarget(focus: focus, period: period)
                } label: {
                    FocusRow(
                        focus: focus,
                        progress: progress[focus.uuid] ?? FocusProgress(),
                        parentTitle: focus.parentUUID.flatMap { id in allFocuses.first { $0.uuid == id }?.title }
                    )
                }
                .foregroundStyle(.primary)
            }
            Button {
                target = EditorTarget(focus: nil, period: period)
            } label: {
                Label(period == .week ? "Фокус недели" : "Фокус месяца", systemImage: "plus")
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Format.locale
        formatter.dateFormat = "LLLL yyyy"
        let date = Recurrence.date(forKey: monthRange.lowerBound, calendar: .current) ?? .now
        return formatter.string(from: date).capitalized
    }

    private func rangeText(_ range: ClosedRange<Int>) -> String {
        let calendar = Calendar.current
        guard let start = Recurrence.date(forKey: range.lowerBound, calendar: calendar),
              let end = Recurrence.date(forKey: range.upperBound, calendar: calendar) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Format.locale
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}

private struct FocusRow: View {
    let focus: Focus
    let progress: FocusProgress
    let parentTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(focus.title)
                    .font(.body.weight(.medium))
                    .strikethrough(focus.status == .dropped)
                Spacer()
                if focus.status != .active {
                    Text(focus.status.title)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (focus.status == .done ? Color.green : Color.gray).opacity(0.2),
                            in: Capsule()
                        )
                }
            }
            if !focus.why.isEmpty {
                Text("Зачем: \(focus.why)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let parentTitle {
                Label(parentTitle, systemImage: "arrow.turn.left.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if progress.totalItems > 0 {
                ProgressView(value: Double(progress.doneItems), total: Double(max(progress.totalItems, 1)))
            }
            Text(progress.text)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Форма фокуса.
struct FocusEditorSheet: View {
    let focus: Focus?
    let period: FocusPeriod
    let periodStartKey: Int
    let activeCount: Int
    let monthFocuses: [Focus]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var why: String
    @State private var parentID: UUID?
    @State private var status: FocusStatus
    @State private var result: String
    @State private var isConfirmingLimit = false
    @State private var isConfirmingDelete = false

    init(focus: Focus?, period: FocusPeriod, periodStartKey: Int, activeCount: Int, monthFocuses: [Focus]) {
        self.focus = focus
        self.period = period
        self.periodStartKey = periodStartKey
        self.activeCount = activeCount
        self.monthFocuses = monthFocuses
        _title = State(initialValue: focus?.title ?? "")
        _why = State(initialValue: focus?.why ?? "")
        _parentID = State(initialValue: focus?.parentUUID)
        _status = State(initialValue: focus?.status ?? .active)
        _result = State(initialValue: focus?.result ?? "")
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(period == .week ? "Например: дописать главу курсовой" : "Например: сдать сессию без долгов",
                              text: $title, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Зачем это мне", text: $why, axis: .vertical)
                        .lineLimit(1...4)
                } footer: {
                    Text("Ответ на «зачем» помогает не бросать, когда трудно: он будет виден рядом с фокусом.")
                }

                if period == .week, !monthFocuses.isEmpty {
                    Section {
                        Picker("Шаг к фокусу месяца", selection: $parentID) {
                            Text("Не связан").tag(UUID?.none)
                            ForEach(monthFocuses) { Text($0.title).tag(UUID?.some($0.uuid)) }
                        }
                    }
                }

                if focus != nil {
                    Section("Итог") {
                        Picker("Статус", selection: $status) {
                            ForEach(FocusStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        TextField("Что получилось, чему научился", text: $result, axis: .vertical)
                            .lineLimit(1...5)
                    }
                    Section {
                        Button("Удалить фокус", role: .destructive) { isConfirmingDelete = true }
                    }
                }
            }
            .navigationTitle(focus == nil ? (period == .week ? "Фокус недели" : "Фокус месяца") : "Фокус")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        if focus == nil, activeCount >= 3 {
                            isConfirmingLimit = true
                        } else {
                            save()
                        }
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog(
                "Это будет \(activeCount + 1)-й фокус",
                isPresented: $isConfirmingLimit,
                titleVisibility: .visible
            ) {
                Button("Да, всё это главное", action: save)
                Button("Подумаю ещё", role: .cancel) {}
            } message: {
                Text("Когда фокусов много, внимание распыляется и ни один не получает достаточно времени. Точно всё это главное?")
            }
            .confirmationDialog("Удалить фокус?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    if let focus { context.delete(focus) }
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("Блоки и записи, привязанные к нему, останутся, но потеряют привязку.")
            }
        }
    }

    private func save() {
        let target = focus ?? {
            let new = Focus(title: trimmedTitle, period: period, periodStartKey: periodStartKey)
            new.sortOrder = activeCount
            context.insert(new)
            return new
        }()
        target.title = trimmedTitle
        target.why = why.trimmingCharacters(in: .whitespacesAndNewlines)
        target.parentUUID = period == .week ? parentID : nil
        target.status = status
        target.result = result
        try? context.save()
        dismiss()
    }
}
