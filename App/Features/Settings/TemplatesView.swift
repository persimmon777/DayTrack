import DayTrackCore
import SwiftData
import SwiftUI

/// Шаблоны дня: просмотр, переименование и удаление.
struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DayTemplate.createdAt) private var templates: [DayTemplate]
    @Query private var categories: [ActivityCategory]

    var body: some View {
        List {
            if templates.isEmpty {
                Text("Шаблонов пока нет. Составь план дня и на вкладке «План» нажми «+» → «Сохранить день как шаблон».")
                    .foregroundStyle(.secondary)
            }
            ForEach(templates) { template in
                NavigationLink {
                    TemplateDetailView(template: template, categories: categories)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                        Text("Блоков: \(template.items.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets { context.delete(templates[index]) }
                try? context.save()
            }
        }
        .navigationTitle("Шаблоны дня")
    }
}

private struct TemplateDetailView: View {
    @Bindable var template: DayTemplate
    let categories: [ActivityCategory]

    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section("Название") {
                TextField("Название", text: $template.name)
                    .onSubmit { try? context.save() }
            }
            Section("Блоки") {
                ForEach(Array(template.items.enumerated()), id: \.offset) { _, item in
                    let category = categories.first { $0.uuid == item.categoryUUID }
                    HStack(spacing: 10) {
                        CategoryBadge(
                            colorHex: category?.colorHex ?? "7F8C8D",
                            symbol: category?.symbol ?? "circle.fill",
                            size: 24
                        )
                        Text(item.title)
                        Spacer()
                        Text("\(ScheduleView.time(item.startMinute))–\(ScheduleView.time(item.startMinute + item.durationMinutes))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    var items = template.items
                    items.remove(atOffsets: offsets)
                    template.items = items
                    try? context.save()
                }
            }
        }
        .navigationTitle(template.name)
        .onDisappear { try? context.save() }
    }
}
