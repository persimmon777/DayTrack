import XCTest
@testable import DayTrackCore

final class WeeklyScheduleTests: XCTestCase {
    private let calendar = TestTime.calendar()
    // 1 сентября 2026 — вторник; первая неделя: 31 августа – 6 сентября.
    private let firstWeek = 20260901

    func testWeekNumbers() {
        XCTAssertEqual(WeeklySchedule.weekNumber(of: 20260831, firstWeekKey: firstWeek, calendar: calendar), 1)
        XCTAssertEqual(WeeklySchedule.weekNumber(of: 20260906, firstWeekKey: firstWeek, calendar: calendar), 1)
        XCTAssertEqual(WeeklySchedule.weekNumber(of: 20260907, firstWeekKey: firstWeek, calendar: calendar), 2)
        // 16 ноября 2026 — понедельник 12-й недели.
        XCTAssertEqual(WeeklySchedule.weekNumber(of: 20261116, firstWeekKey: firstWeek, calendar: calendar), 12)
        XCTAssertEqual(WeeklySchedule.weekNumber(of: 20260830, firstWeekKey: firstWeek, calendar: calendar), 0)
    }

    func testWeekdayAndParity() {
        let mondayOdd = ScheduleRuleData(weekday: 2, parity: .odd)
        let mondayEven = ScheduleRuleData(weekday: 2, parity: .even)
        let mondayEvery = ScheduleRuleData(weekday: 2, parity: .every)

        // 9 ноября — 11-я неделя (нечётная), 16 ноября — 12-я (чётная).
        XCTAssertTrue(WeeklySchedule.applies(mondayOdd, on: 20261109, firstWeekKey: firstWeek, calendar: calendar))
        XCTAssertFalse(WeeklySchedule.applies(mondayOdd, on: 20261116, firstWeekKey: firstWeek, calendar: calendar))
        XCTAssertTrue(WeeklySchedule.applies(mondayEven, on: 20261116, firstWeekKey: firstWeek, calendar: calendar))
        XCTAssertTrue(WeeklySchedule.applies(mondayEvery, on: 20261116, firstWeekKey: firstWeek, calendar: calendar))
        XCTAssertFalse(WeeklySchedule.applies(mondayEvery, on: 20261117, firstWeekKey: firstWeek, calendar: calendar))
    }

    func testPeriodAndDisabled() {
        var rule = ScheduleRuleData(weekday: 2, parity: .every, validFromKey: 20261110, validUntilKey: 20261220)
        XCTAssertFalse(WeeklySchedule.applies(rule, on: 20261109, firstWeekKey: firstWeek, calendar: calendar))
        XCTAssertTrue(WeeklySchedule.applies(rule, on: 20261116, firstWeekKey: firstWeek, calendar: calendar))
        XCTAssertFalse(WeeklySchedule.applies(rule, on: 20261221, firstWeekKey: firstWeek, calendar: calendar))
        rule.isEnabled = false
        XCTAssertFalse(WeeklySchedule.applies(rule, on: 20261116, firstWeekKey: firstWeek, calendar: calendar))
    }

    func testDefaultAcademicYearStart() {
        XCTAssertEqual(WeeklySchedule.defaultFirstWeekKey(today: 20261116), 20260901)
        XCTAssertEqual(WeeklySchedule.defaultFirstWeekKey(today: 20270310), 20260901)
        XCTAssertEqual(WeeklySchedule.defaultFirstWeekKey(today: 20270901), 20270901)
    }
}
