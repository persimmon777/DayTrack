import DayTrackCore
import SwiftData
import SwiftUI

/// Список категорий: порядок, добавление, правка, архив.
struct CategoriesView: View {
    /// Что открыто в форме: новая категория или существующая.
    private struct EditorTarget: Identifiable {
        let id = UUID()
        let category: ActivityCategory?
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \ActivityCategory.sortOrder) private var categories: [ActivityCategory]

    @State private var editorTarget: EditorTarget?

    private var active: [ActivityCategory] { categories.filter { !$0.isArchived } }
    private var archived: [ActivityCategory] { categories.filter(\.isArchived) }

    var body: some View {
        List {
            Section {
                ForEach(active) { category in
                    Button {
                        editorTarget = EditorTarget(category: category)
                    } label: {
                        row(category)
                    }
                    .foregroundStyle(.primary)
                }
                .onMove(perform: move)
                .onDelete(perform: remove)
            } footer: {
                Text("Категорию, которая уже использовалась, удалить нельзя: она уходит в архив, а старые записи сохраняют её название и цвет.")
            }

            if !archived.isEmpty {
                Section("Архив") {
                    ForEach(archived) { category in
                        row(category)
                            .swipeActions {
                                Button("Вернуть") {
                                    category.isArchived = false
                                    category.sortOrder = (categories.map(\.sortOrder).max() ?? 0) + 1
                                    try? context.save()
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .navigationTitle("Категории")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button {
                    editorTarget = EditorTarget(category: nil)
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            CategoryEditorView(
                category: target.category,
                nextSortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1
            )
        }
    }

    private func row(_ category: ActivityCategory) -> some View {
        HStack(spacing: 12) {
            CategoryBadge(colorHex: category.colorHex, symbol: category.symbol)
            VStack(alignment: .leading, spacing: 1) {
                Text(category.name)
                Text(category.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var items = active
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }
        try? context.save()
    }

    private func remove(at offsets: IndexSet) {
        let items = active
        for index in offsets {
            let category = items[index]
            if category.isInUse {
                category.isArchived = true
            } else {
                context.delete(category)
            }
        }
        try? context.save()
    }
}

/// Форма категории.
struct CategoryEditorView: View {
    let category: ActivityCategory?
    let nextSortOrder: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String
    @State private var kind: CategoryKind
    @State private var colorHex: String
    @State private var symbol: String

    init(category: ActivityCategory?, nextSortOrder: Int) {
        self.category = category
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: category?.name ?? "")
        _kind = State(initialValue: category?.kind ?? .study)
        _colorHex = State(initialValue: category?.colorHex ?? CategoryPalette.colors[0])
        _symbol = State(initialValue: category?.symbol ?? CategoryPalette.symbols[0])
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CategoryBadge(colorHex: colorHex, symbol: symbol, size: 36)
                        TextField("Название", text: $name)
                    }
                    Picker("Тип", selection: $kind) {
                        ForEach(CategoryKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                } footer: {
                    Text("По типу считается баланс: например, «Пары» и «Самообразование» вместе идут в учёбу.")
                }

                Section("Цвет") {
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(CategoryPalette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(height: 36)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark")
                                            .font(.footnote.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Значок") {
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(CategoryPalette.symbols, id: \.self) { name in
                            Image(systemName: name)
                                .font(.body)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(
                                    name == symbol ? Color(hex: colorHex).opacity(0.25) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { symbol = name }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "Новая категория" : "Категория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let category {
            category.name = trimmedName
            category.kind = kind
            category.colorHex = colorHex
            category.symbol = symbol
        } else {
            context.insert(ActivityCategory(
                name: trimmedName,
                colorHex: colorHex,
                symbol: symbol,
                kind: kind,
                sortOrder: nextSortOrder
            ))
        }
        try? context.save()
        dismiss()
    }
}
