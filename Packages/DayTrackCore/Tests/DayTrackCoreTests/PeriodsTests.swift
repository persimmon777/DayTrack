import XCTest
@testable import DayTrackCore

final class PeriodsTests: XCTestCase {
    private let calendar = TestTime.calendar()

    func testWeekRangeStartsOnMonday() {
        // 18 ноября 2026 — среда.
        XCTAssertEqual(Periods.range(.week, containing: 20261118, calendar: calendar), 20261116...20261122)
        XCTAssertEqual(Periods.range(.week, containing: 20261122, calendar: calendar), 20261116...20261122)
        XCTAssertEqual(Periods.range(.week, containing: 20261231, calendar: calendar), 20261228...20270103)
    }

    func testMonthRange() {
        XCTAssertEqual(Periods.range(.month, containing: 20260215, calendar: calendar), 20260201...20260228)
        XCTAssertEqual(Periods.range(.month, containing: 20281105, calendar: calendar), 20281101...20281130)
    }

    func testShift() {
        XCTAssertEqual(Periods.shift(20261118, kind: .week, by: 1, calendar: calendar), 20261125)
        XCTAssertEqual(Periods.shift(20260131, kind: .month, by: 1, calendar: calendar), 20260228)
        XCTAssertEqual(Periods.shift(20260115, kind: .month, by: -1, calendar: calendar), 20251215)
        XCTAssertEqual(Periods.shift(20261215, kind: .month, by: 13, calendar: calendar), 20280115)
        XCTAssertEqual(Periods.shift(20261231, kind: .day, by: 1, calendar: calendar), 20270101)
    }

    func testDaysInRange() {
        XCTAssertEqual(Periods.days(in: 20261230...20270102, calendar: calendar), [20261230, 20261231, 20270101, 20270102])
    }
}
