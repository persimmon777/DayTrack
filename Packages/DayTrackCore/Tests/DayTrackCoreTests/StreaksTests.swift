import XCTest
@testable import DayTrackCore

final class StreaksTests: XCTestCase {
    private let calendar = TestTime.calendar()
    // 19 ноября 2026 — четверг.
    private let today = 20261119

    private func streak(_ keys: [Int]) -> Int {
        Streaks.softStreak(doneKeys: Set(keys), today: today, calendar: calendar)
    }

    func testConsecutiveDays() {
        XCTAssertEqual(streak([20261117, 20261118, 20261119]), 3)
        // Сегодня ещё не закрыт — серия держится на вчерашнем дне.
        XCTAssertEqual(streak([20261117, 20261118]), 2)
    }

    func testOneMissPerWeekIsForgiven() {
        // 17-е пропущено, неделя 16–22: один пропуск прощён и входит в серию.
        XCTAssertEqual(streak([20261116, 20261118, 20261119]), 4)
    }

    func testSecondMissInSameWeekBreaks() {
        XCTAssertEqual(streak([20261116, 20261119]), 1)
    }

    func testForgivenMissNeedsDaysBeforeIt() {
        XCTAssertEqual(streak([]), 0)
        XCTAssertEqual(streak([20261119]), 1)
    }

    func testMissesInDifferentWeeksAreEachForgiven() {
        // 13 (пт) пропущено в прошлой неделе, 17 (вт) — в этой.
        let keys = [20261111, 20261112, 20261114, 20261115, 20261116, 20261118, 20261119]
        XCTAssertEqual(streak(keys), 9)
    }

    func testCountInLastDays() {
        XCTAssertEqual(Streaks.count(doneKeys: [20261119, 20261101, 20261020], lastDays: 30, today: today, calendar: calendar), 2)
    }
}
