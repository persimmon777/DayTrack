import XCTest
@testable import DayTrackCore

final class TimelineLayoutTests: XCTestCase {
    private typealias Span = TimelineLayout.Span
    private typealias Slot = TimelineLayout.Slot

    func testSeparateBlocksTakeFullWidth() {
        let slots = TimelineLayout.layout([Span(start: 0, end: 60), Span(start: 60, end: 120)])
        XCTAssertEqual(slots, [Slot(column: 0, columnCount: 1), Slot(column: 0, columnCount: 1)])
    }

    func testOverlappingBlocksStandSideBySide() {
        let slots = TimelineLayout.layout([Span(start: 0, end: 60), Span(start: 30, end: 90)])
        XCTAssertEqual(slots, [Slot(column: 0, columnCount: 2), Slot(column: 1, columnCount: 2)])
    }

    func testFreedColumnIsReusedWithinGroup() {
        let slots = TimelineLayout.layout([
            Span(start: 0, end: 120),
            Span(start: 10, end: 40),
            Span(start: 50, end: 100),
        ])
        XCTAssertEqual(slots, [
            Slot(column: 0, columnCount: 2),
            Slot(column: 1, columnCount: 2),
            Slot(column: 1, columnCount: 2),
        ])
    }

    func testResultKeepsInputOrder() {
        let slots = TimelineLayout.layout([
            Span(start: 200, end: 260),
            Span(start: 0, end: 60),
            Span(start: 30, end: 90),
        ])
        XCTAssertEqual(slots, [
            Slot(column: 0, columnCount: 1),
            Slot(column: 0, columnCount: 2),
            Slot(column: 1, columnCount: 2),
        ])
    }

    func testEmptyInput() {
        XCTAssertEqual(TimelineLayout.layout([]), [])
    }
}
