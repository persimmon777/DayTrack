import XCTest
@testable import DayTrackCore

final class KeywordMatcherTests: XCTestCase {
    func testParseNormalizesAndDropsDuplicates() {
        XCTAssertEqual(
            KeywordMatcher.parse("Тренировка, ЗАЛ;  бег\nзал, а, День  рождения"),
            ["тренировка", "зал", "бег", "день рождения"]
        )
        XCTAssertEqual(KeywordMatcher.parse("Ёлка"), ["елка"])
        XCTAssertEqual(KeywordMatcher.parse(""), [])
    }

    func testKeywordMatchesWordBeginning() {
        XCTAssertNotNil(KeywordMatcher.score(title: "Тренировка в зале", keywords: ["трениров"]))
        XCTAssertNotNil(KeywordMatcher.score(title: "Подготовка к экзамену!", keywords: ["экзамен"]))
        XCTAssertNil(KeywordMatcher.score(title: "Подготовка к экзамену", keywords: ["готов"]))
        XCTAssertNil(KeywordMatcher.score(title: "", keywords: ["сон"]))
    }

    func testPhraseMatchesConsecutiveWords() {
        let keywords = ["день рожд"]
        XCTAssertNotNil(KeywordMatcher.score(title: "У Маши день рождения", keywords: keywords))
        XCTAssertNil(KeywordMatcher.score(title: "рождения день", keywords: keywords))
        XCTAssertNil(KeywordMatcher.score(title: "день", keywords: keywords))
    }

    func testLongerMatchWinsThenEarlierCandidate() {
        let candidates = [["курс"], ["курсов"], ["курсов"]]
        XCTAssertEqual(KeywordMatcher.bestMatch(title: "Пишу курсовую", candidates: candidates), 1)
        XCTAssertEqual(KeywordMatcher.bestMatch(title: "Курсы по Swift", candidates: candidates), 0)
        XCTAssertNil(KeywordMatcher.bestMatch(title: "Обед", candidates: candidates))
    }

    func testIgnoresCaseAndYo() {
        XCTAssertNotNil(KeywordMatcher.score(title: "ЁЖИК в тумане", keywords: ["ежик"]))
    }
}
