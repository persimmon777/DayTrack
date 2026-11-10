import SwiftUI

/// Экран этапа 0: проверяет, что после установки работают общая папка,
/// виджет, таймер на экране блокировки и уведомления.
struct InstallCheckView: View {
    @State private var model = InstallCheckModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                Text("Пройди четыре проверки по порядку, затем нажми «Скопировать результат» внизу и пришли текст.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LabeledContent("Версия", value: model.appVersion)
            }

            containerSection
            widgetSection
            timerSection
            notificationSection

            Section {
                Button {
                    model.copyReport()
                } label: {
                    Label(
                        model.copied ? "Скопировано" : "Скопировать результат",
                        systemImage: model.copied ? "checkmark" : "doc.on.doc"
                    )
                }
            } footer: {
                Text("Текст попадёт в буфер обмена. В нём только технические данные этой проверки.")
            }
        }
        .navigationTitle("Проверка установки")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.refresh() }
        }
    }

    // MARK: 1. Общая папка

    private var containerSection: some View {
        Section {
            if let groupID = model.container.groupID {
                StatusRow(.ok, "Общая папка доступна")
                Text(groupID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                StatusRow(.failed, "Общая папка недоступна")
                Text("Виджет не сможет получать данные из приложения. Пришли результат проверки, будем искать обход.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("1. Общая папка")
        } footer: {
            Text("Через неё приложение передаёт данные виджету.")
        }
    }

    // MARK: 2. Виджет

    private var widgetSection: some View {
        Section {
            Button("Записать новое число") {
                model.writeNumber()
                Task {
                    // Виджету нужно немного времени, чтобы перерисоваться и ответить.
                    try? await Task.sleep(for: .seconds(2))
                    await model.refresh()
                }
            }
            OutcomeRow(outcome: model.writeOutcome)

            if model.widgetConfirmed {
                StatusRow(.ok, "Виджет прочитал число \(model.number)")
            } else if let ack = model.widgetAck {
                StatusRow(.pending, "Виджет показывал \(ack.number), новое число пока не прочитал")
            } else {
                StatusRow(.pending, "Виджет ещё ничего не читал")
            }

            if let count = model.placedWidgetCount {
                LabeledContent("Виджетов на экране", value: "\(count)")
            }
        } header: {
            Text("2. Виджет")
        } footer: {
            Text("Добавь на домашний экран виджет «Проверка DayTrack», затем нажми кнопку. Виджет должен показать то же число. Потяни список вниз, чтобы обновить статус.")
        }
    }

    // MARK: 3. Таймер

    private var timerSection: some View {
        Section {
            Button("Запустить таймер на 1 минуту") {
                Task { await model.startTimer() }
            }
            OutcomeRow(outcome: model.timerOutcome)
            Button("Убрать таймер", role: .destructive) {
                Task { await model.stopTimer() }
            }
        } header: {
            Text("3. Таймер на экране блокировки")
        } footer: {
            Text("После запуска заблокируй телефон: на экране блокировки должен идти обратный отсчёт.")
        }
    }

    // MARK: 4. Уведомления

    private var notificationSection: some View {
        Section {
            Button("Прислать уведомление через 10 секунд") {
                Task { await model.sendNotification() }
            }
            OutcomeRow(outcome: model.notificationOutcome)
            LabeledContent("Разрешение", value: model.notificationStatus)
        } header: {
            Text("4. Уведомления")
        } footer: {
            Text("При первом нажатии iPhone спросит разрешение. Нажми «Разрешить».")
        }
    }
}

// MARK: - Строки состояния

private struct StatusRow: View {
    enum Kind {
        case ok, failed, pending
    }

    let kind: Kind
    let text: String

    init(_ kind: Kind, _ text: String) {
        self.kind = kind
        self.text = text
    }

    var body: some View {
        Label {
            Text(text)
        } icon: {
            switch kind {
            case .ok:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
            case .pending:
                Image(systemName: "clock").foregroundStyle(.secondary)
            }
        }
    }
}

private struct OutcomeRow: View {
    let outcome: InstallCheckModel.Outcome

    var body: some View {
        switch outcome {
        case .notRun:
            EmptyView()
        case .ok(let message):
            StatusRow(.ok, message)
        case .failed(let message):
            StatusRow(.failed, message)
        }
    }
}
