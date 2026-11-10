import SwiftUI
import WidgetKit

/// Тестовый виджет этапа 0: показывает число, записанное приложением.
/// Нужен, чтобы убедиться, что виджет устанавливается и получает данные.
struct InstallCheckWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: InstallCheckStore.widgetKind, provider: InstallCheckProvider()) { entry in
            InstallCheckWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Проверка DayTrack")
        .description("Показывает число, записанное приложением.")
        .supportedFamilies([.systemSmall])
    }
}

struct InstallCheckEntry: TimelineEntry {
    enum Content {
        case number(Int, writtenAt: Date)
        case noContainer
        case noData
        case unreadable
    }

    let date: Date
    let content: Content
}

struct InstallCheckProvider: TimelineProvider {
    func placeholder(in context: Context) -> InstallCheckEntry {
        InstallCheckEntry(date: .now, content: .number(42, writtenAt: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (InstallCheckEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry(acknowledge: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InstallCheckEntry>) -> Void) {
        // Приложение само просит перерисовать виджет после записи числа,
        // поэтому обновление по расписанию не нужно.
        completion(Timeline(entries: [currentEntry(acknowledge: true)], policy: .never))
    }

    private func currentEntry(acknowledge: Bool) -> InstallCheckEntry {
        let content: InstallCheckEntry.Content
        switch InstallCheckStore.readSnapshot() {
        case .success(let snapshot):
            content = .number(snapshot.number, writtenAt: snapshot.writtenAt)
            if acknowledge {
                InstallCheckStore.writeAck(InstallCheckAck(number: snapshot.number, readAt: .now))
            }
        case .failure(.noContainer):
            content = .noContainer
        case .failure(.noData):
            content = .noData
        case .failure(.unreadable):
            content = .unreadable
        }
        return InstallCheckEntry(date: .now, content: content)
    }
}

struct InstallCheckWidgetView: View {
    let entry: InstallCheckEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DayTrack")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            switch entry.content {
            case .number(let number, let writtenAt):
                Text("\(number)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("записано в \(writtenAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .noContainer:
                message("Нет общей папки", detail: "Виджет не видит данные приложения")
            case .noData:
                message("Числа ещё нет", detail: "Запиши его в приложении")
            case .unreadable:
                message("Данные повреждены", detail: "Запиши число заново")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func message(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
