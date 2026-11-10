import XCTest
@testable import DayTrackCore

final class DurationTextTests: XCTestCase {
    func testShortDurations() {
        XCTAssertEqual(DurationText.short(minutes: 0), "0 мин")
        XCTAssertEqual(DurationText.short(minutes: 45), "45 мин")
        XCTAssertEqual(DurationText.short(minutes: 120), "2 ч")
        XCTAssertEqual(DurationText.short(minutes: 90), "1 ч 30 мин")
        XCTAssertEqual(DurationText.short(minutes: -5), "0 мин")
    }

    func testPercent() {
        XCTAssertEqual(DurationText.percent(0.584), "58%")
        XCTAssertEqual(DurationText.percent(1), "100%")
    }
}
