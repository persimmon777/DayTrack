import DayTrackCore
import Foundation

extension ActivityCategory {
    var keywords: [String] { KeywordMatcher.parse(keywordsRaw) }
}

enum CategoryKeywords {
    /// Категория, к которой по ключевым словам относится название. Архивные не участвуют.
    static func match(title: String, in categories: [ActivityCategory]) -> ActivityCategory? {
        let active = categories.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
        guard let index = KeywordMatcher.bestMatch(title: title, candidates: active.map(\.keywords)) else {
            return nil
        }
        return active[index]
    }
}
