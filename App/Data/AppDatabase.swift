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
    private static let defaultCategories: [(name: String, color: String, symbol: String, kind: CategoryKind, keywords: String)] = [
        ("Пары", "4F7BE8", "graduationcap.fill", .study,
         "пара, пары, лекци, семинар, практическ, лаб, коллоквиум, консультаци"),
        ("Учёба", "6C5CE7", "book.fill", .study,
         "учеб, домашк, дз, курсов, реферат, доклад, экзамен, зачет, сессия, подготовк, конспект, матан, математ, физик, химия, история, диплом"),
        ("Самообразование", "A55EEA", "lightbulb.fill", .study,
         "курс, курсы, книг, чтение, читать, статья, лекция на youtube, вебинар, программирован, английск, язык"),
        ("Отдых", "6AB04C", "leaf.fill", .rest,
         "отдых, перерыв, прогулк, гулять, сериал, фильм, кино, игр, друз, ютуб, youtube, музык"),
        ("Сон", "3C6382", "moon.fill", .sleep, "сон, спать, сплю, дневной сон"),
        ("Спорт", "F0932B", "figure.run", .sport,
         "спорт, зал, трениров, бег, пробежк, футбол, баскетбол, бассейн, плавани, йога, зарядк, растяжк"),
        ("Еда", "E1B12C", "fork.knife", .routine, "завтрак, обед, ужин, перекус, еда, готовк"),
        ("Быт", "8D6E63", "house.fill", .routine,
         "уборк, убраться, стирк, магазин, покупк, продукт, посуд, душ"),
        ("Дорога", "22A6B3", "tram.fill", .transit,
         "дорог, метро, автобус, такси, электричк, поездк, доехать, ехать"),
        ("Работа", "EB4D4B", "briefcase.fill", .work, "работ, смена, созвон, подработк"),
        ("Другое", "7F8C8D", "circle.grid.2x2.fill", .other, "врач, больниц, поликлиник, день рожд"),
    ]

    private static let keywordsSeededKey = "keywordsSeeded.v1"

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ActivityCategory>())) ?? []
        if existing.isEmpty {
            for (index, item) in defaultCategories.enumerated() {
                let category = ActivityCategory(
                    name: item.name, colorHex: item.color, symbol: item.symbol,
                    kind: item.kind, sortOrder: index
                )
                category.keywordsRaw = item.keywords
                context.insert(category)
            }
        } else if !UserDefaults.standard.bool(forKey: keywordsSeededKey) {
            // Категории из прошлых версий получают ключевые слова один раз,
            // если пользователь ещё не задал свои.
            for category in existing where category.keywordsRaw.isEmpty {
                if let item = defaultCategories.first(where: { $0.name == category.name }) {
                    category.keywordsRaw = item.keywords
                }
            }
        }
        UserDefaults.standard.set(true, forKey: keywordsSeededKey)
        try? context.save()
    }
}
