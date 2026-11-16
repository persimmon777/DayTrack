import Foundation

/// Подбор категории по словам в названии дела.
///
/// Ключевое слово срабатывает как начало слова: «трениров» подходит к
/// «тренировка» и «тренировки», но не к «претренировочный». Можно задавать
/// фразы из нескольких слов. Регистр и «ё»/«е» не различаются.
public enum KeywordMatcher {
    public static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Слова текста без знаков препинания.
    public static func words(_ text: String) -> [String] {
        normalize(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Список ключевых слов из строки «через запятую». Слишком короткие
    /// (одна буква) и повторы отбрасываются.
    public static func parse(_ raw: String) -> [String] {
        var result: [String] = []
        for part in raw.components(separatedBy: CharacterSet(charactersIn: ",;\n")) {
            let phrase = words(part).joined(separator: " ")
            guard phrase.count >= 2, !result.contains(phrase) else { continue }
            result.append(phrase)
        }
        return result
    }

    /// Длина самого длинного совпавшего ключевого слова или `nil`.
    public static func score(title: String, keywords: [String]) -> Int? {
        let titleWords = words(title)
        guard !titleWords.isEmpty else { return nil }
        var best: Int?
        for keyword in keywords {
            let parts = keyword.split(separator: " ").map(String.init)
            guard !parts.isEmpty, parts.count <= titleWords.count else { continue }
            for offset in 0...(titleWords.count - parts.count) {
                let matches = parts.indices.allSatisfy { index in
                    let word = titleWords[offset + index]
                    // Последнее слово фразы может быть началом слова, остальные — целыми.
                    return index == parts.count - 1 ? word.hasPrefix(parts[index]) : word == parts[index]
                }
                if matches {
                    best = max(best ?? 0, keyword.count)
                    break
                }
            }
        }
        return best
    }

    /// Номер подходящего набора ключевых слов. При равенстве побеждает
    /// более длинное совпадение, затем набор, стоящий раньше.
    public static func bestMatch(title: String, candidates: [[String]]) -> Int? {
        var best: (index: Int, score: Int)?
        for (index, keywords) in candidates.enumerated() {
            guard let score = score(title: title, keywords: keywords) else { continue }
            if score > (best?.score ?? 0) { best = (index, score) }
        }
        return best?.index
    }
}
