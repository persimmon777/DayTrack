import XCTest
@testable import DayTrackCore

final class DayClockTests: XCTestCase {
    private let clock = DayClock(calendar: TestTime.calendar(), startHour: 4)

    func testNightBelongsToPreviousDay() {
        XCTAssertEqual(clock.key(for: TestTime.date(2026, 11, 10, 12, 0)), 20261110)
        XCTAssertEqual(clock.key(for: TestTime.date(2026, 11, 11, 2, 0)), 20261110)
        XCTAssertEqual(clock.key(for: TestTime.date(2026, 11, 11, 3, 59)), 20261110)
        XCTAssertEqual(clock.key(for: TestTime.date(2026, 11, 11, 4, 0)), 20261111)
    }

    func testKeyAcrossMonthAndYear() {
        XCTAssertEqual(clock.key(for: TestTime.date(2027, 1, 1, 1, 0)), 20261231)
        XCTAssertEqual(clock.key(byAdding: 1, to: 20261231), 20270101)
        XCTAssertEqual(clock.key(byAdding: -1, to: 20260301), 20260228)
        XCTAssertEqual(clock.key(byAdding: 7, to: 20261128), 20261205)
    }

    func testWindowIsFromStartHourToNextStartHour() throws {
        let window = try XCTUnwrap(clock.window(forKey: 20261110))
        XCTAssertEqual(window.start, TestTime.date(2026, 11, 10, 4, 0))
        XCTAssertEqual(window.end, TestTime.date(2026, 11, 11, 4, 0))
        XCTAssertEqual(clock.key(for: window.start), 20261110)
        XCTAssertEqual(clock.key(for: window.end.addingTimeInterval(-1)), 20261110)
    }

    func testInvalidKeyHasNoWindow() {
        XCTAssertNil(clock.window(forKey: 20260231))
        XCTAssertNil(clock.calendarDate(forKey: 20261301))
    }

    func testResolvePutsEarlyHoursOnNextCalendarDate() {
        XCTAssertEqual(
            clock.resolve(hour: 9, minute: 30, inDay: 20261110),
            TestTime.date(2026, 11, 10, 9, 30)
        )
        XCTAssertEqual(
            clock.resolve(hour: 1, minute: 30, inDay: 20261110),
            TestTime.date(2026, 11, 11, 1, 30)
        )
        XCTAssertEqual(
            clock.resolve(hour: 4, minute: 0, inDay: 20261110),
            TestTime.date(2026, 11, 10, 4, 0)
        )
    }

    func testResolvedTimeAlwaysFallsInsideWindow() throws {
        let window = try XCTUnwrap(clock.window(forKey: 20261110))
        for hour in 0..<24 {
            let date = try XCTUnwrap(clock.resolve(hour: hour, minute: 15, inDay: 20261110))
            XCTAssertTrue(window.contains(date), "час \(hour)")
            XCTAssertEqual(clock.key(for: date), 20261110, "час \(hour)")
        }
    }

    func testEndAfterStartCrossesMidnight() {
        let start = TestTime.date(2026, 11, 10, 23, 30)
        XCTAssertEqual(clock.end(after: start, hour: 7, minute: 30), TestTime.date(2026, 11, 11, 7, 30))
        XCTAssertEqual(clock.end(after: start, hour: 23, minute: 45), TestTime.date(2026, 11, 10, 23, 45))
        // То же время на часах означает ровно сутки, а не нулевую длительность.
        XCTAssertEqual(clock.end(after: start, hour: 23, minute: 30), TestTime.date(2026, 11, 11, 23, 30))
    }

    func testMidnightStartHourBehavesLikeCalendarDay() throws {
        let midnight = DayClock(calendar: TestTime.calendar(), startHour: 0)
        XCTAssertEqual(midnight.key(for: TestTime.date(2026, 11, 11, 0, 0)), 20261111)
        XCTAssertEqual(midnight.key(for: TestTime.date(2026, 11, 10, 23, 59)), 20261110)
        XCTAssertEqual(
            midnight.resolve(hour: 0, minute: 30, inDay: 20261110),
            TestTime.date(2026, 11, 10, 0, 30)
        )
    }

    func testWindowOnDaylightSavingDayIsShorter() throws {
        let berlin = DayClock(calendar: TestTime.calendar(timeZone: "Europe/Berlin"), startHour: 0)
        let window = try XCTUnwrap(berlin.window(forKey: 20260329))
        XCTAssertEqual(window.duration, 23 * 3600)
    }
}
