import DayTrackCore
import Foundation
import SwiftData

/// Открытие базы данных и первичное наполнение.
enum AppDatabase {
    static let models: [any PersistentModel.Type] = [
        ActivityCategory.self,
        Day.self,
        PlannedBlock.self,
        TaskItem.self,
        FactEntry.self,
        PlanChange.self,
    ]

    /// База хранится в папке самого приложения. Новые поля и сущности
    /// добавляются в неё автоматически при обновлении.
    static func openContainer() -> Result<ModelContainer, Error> {
        Result { try ModelContainer(for: Schema(models)) }
    }

    /// Категории, с которых начинает студент. Их можно менять и удалять.
    private static let defaultCategories: [(String, String, String, CategoryKind)] = [
        ("Пары", "4F7BE8", "graduationcap.fill", .study),
        ("Учёба", "6C5CE7", "book.fill", .study),
        ("Самообразование", "A55EEA", "lightbulb.fill", .study),
        ("Отдых", "6AB04C", "leaf.fill", .rest),
        ("Сон", "3C6382", "moon.fill", .sleep),
        ("Спорт", "F0932B", "figure.run", .sport),
        ("Еда", "E1B12C", "fork.knife", .routine),
        ("Быт", "8D6E63", "house.fill", .routine),
        ("Дорога", "22A6B3", "tram.fill", .transit),
        ("Работа", "EB4D4B", "briefcase.fill", .work),
        ("Другое", "7F8C8D", "circle.grid.2x2.fill", .other),
    ]

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<ActivityCategory>())) ?? 0
        guard existing == 0 else { return }
        for (index, item) in defaultCategories.enumerated() {
            context.insert(ActivityCategory(
                name: item.0,
                colorHex: item.1,
                symbol: item.2,
                kind: item.3,
                sortOrder: index
            ))
        }
        try? context.save()
    }
}
