import XCTest
@testable import DayTrackCore

final class RecurrenceTests: XCTestCase {
    private let calendar = TestTime.calendar()

    private func occurs(_ key: Int, _ first: Int, _ rule: RepeatRule) -> Bool {
        Recurrence.occurs(on: key, first: first, rule: rule, calendar: calendar)
    }

    func testOneTimeOnlyOnItsDay() {
        XCTAssertTrue(occurs(20261120, 20261120, .none))
        XCTAssertFalse(occurs(20261121, 20261120, .none))
    }

    func testNothingBeforeFirstDate() {
        XCTAssertFalse(occurs(20251120, 20261120, .yearly))
        XCTAssertFalse(occurs(20261113, 20261120, .weekly))
    }

    func testWeeklyOnSameWeekday() {
        // 20 ноября 2026 — пятница.
        XCTAssertTrue(occurs(20261127, 20261120, .weekly))
        XCTAssertTrue(occurs(20270101, 20261120, .weekly))
        XCTAssertFalse(occurs(20261128, 20261120, .weekly))
    }

    func testMonthlyClampsToShortMonths() {
        XCTAssertTrue(occurs(20261215, 20261115, .monthly))
        XCTAssertTrue(occurs(20270228, 20270131, .monthly))
        XCTAssertFalse(occurs(20270227, 20270131, .monthly))
        XCTAssertTrue(occurs(20270331, 20270131, .monthly))
        XCTAssertTrue(occurs(20270430, 20270131, .monthly))
    }

    func testYearlyBirthdayAndLeapDay() {
        XCTAssertTrue(occurs(20270312, 20000312, .yearly))
        XCTAssertFalse(occurs(20270313, 20000312, .yearly))
        XCTAssertTrue(occurs(20270228, 20000229, .yearly))
        XCTAssertTrue(occurs(20280229, 20000229, .yearly))
        XCTAssertFalse(occurs(20280228, 20000229, .yearly))
    }

    func testOccurrencesInRange() {
        XCTAssertEqual(
            Recurrence.occurrences(first: 20261120, rule: .weekly, from: 20261116, through: 20261210, calendar: calendar),
            [20261120, 20261127, 20261204]
        )
        XCTAssertEqual(
            Recurrence.occurrences(first: 20000312, rule: .yearly, from: 20261116, through: 20280401, calendar: calendar),
            [20270312, 20280312]
        )
        XCTAssertEqual(
            Recurrence.occurrences(first: 20261120, rule: .none, from: 20261121, through: 20261231, calendar: calendar),
            []
        )
    }

    func testKeyArithmetic() {
        XCTAssertEqual(Recurrence.key(20261231, addingDays: 1, calendar: calendar), 20270101)
        XCTAssertEqual(Recurrence.key(20260301, addingDays: -1, calendar: calendar), 20260228)
    }
}
