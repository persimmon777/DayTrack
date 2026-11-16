import XCTest
@testable import DayTrackCore

final class PeriodStatsTests: XCTestCase {
    private func at(_ hour: Int, _ minute: Int = 0) -> Date { TestTime.date(2026, 11, 16, hour, minute) }

    func testMinutesByKindAndCategory() {
        let facts = [
            StatsFact(start: at(9), end: at(10, 30), categoryID: "math", kind: .study),
            StatsFact(start: at(11), end: at(12), categoryID: "math", kind: .study),
            StatsFact(start: at(12), end: at(13), categoryID: nil, kind: .rest),
        ]
        XCTAssertEqual(PeriodStats.minutesByKind(facts), [.study: 150, .rest: 60])
        XCTAssertEqual(PeriodStats.minutesByCategory(facts), ["math": 150, nil: 60])
    }

    func testReasonCountsDefaultToOther() {
        let plan = UUID()
        let facts = [
            StatsFact(start: at(9), end: at(10), categoryID: nil, kind: .rest, reason: .phone),
            StatsFact(start: at(10), end: at(11), categoryID: nil, kind: .rest, reason: .phone),
            StatsFact(start: at(11), end: at(12), categoryID: nil, kind: .rest),
            StatsFact(start: at(12), end: at(13), categoryID: nil, kind: .study, planID: plan, reason: .fatigue),
        ]
        let missed = [StatsBlock(id: UUID(), start: at(15), end: at(16), categoryID: nil, kind: .study, missReason: .suddenTask)]
        let counts = PeriodStats.reasonCounts(facts: facts, missedBlocks: missed)
        XCTAssertEqual(counts.map(\.reason), [.phone, .suddenTask, .other])
        XCTAssertEqual(counts.map(\.count), [2, 1, 1])
    }

    func testAverageByHour() {
        let result = PeriodStats.averageByHour(
            [(at(10), 4), (at(10, 40), 2), (at(19), 5)],
            calendar: TestTime.calendar()
        )
        XCTAssertEqual(result, [10: 3, 19: 5])
    }

    func testEstimateRatiosUseMedian() {
        let a = UUID(), b = UUID(), c = UUID()
        let blocks = [
            StatsBlock(id: a, start: at(9), end: at(10), categoryID: "math", kind: .study),
            StatsBlock(id: b, start: at(11), end: at(12), categoryID: "math", kind: .study),
            StatsBlock(id: c, start: at(13), end: at(14), categoryID: "math", kind: .study),
        ]
        let facts = [
            StatsFact(start: at(9), end: at(10, 30), categoryID: "math", kind: .study, planID: a),
            StatsFact(start: at(11), end: at(13), categoryID: "math", kind: .study, planID: b),
            StatsFact(start: at(13), end: at(14), categoryID: "math", kind: .study, planID: c),
        ]
        XCTAssertEqual(PeriodStats.estimateRatios(blocks: blocks, facts: facts)["math"] ?? 0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(PeriodStats.median([1, 3]), 2)
        XCTAssertEqual(PeriodStats.median([]), 0)
    }

    func testFocusMinutesInheritFromBlockAndRollUp() {
        let week = UUID(), month = UUID(), block = UUID()
        let facts = [
            StatsFact(start: at(9), end: at(10), categoryID: nil, kind: .study, planID: block),
            StatsFact(start: at(11), end: at(11, 30), categoryID: nil, kind: .study, focusID: month),
            StatsFact(start: at(12), end: at(13), categoryID: nil, kind: .rest),
        ]
        let result = PeriodStats.focusMinutes(facts: facts, blockFocus: [block: week], parentOf: [week: month])
        XCTAssertEqual(result, [week: 60, month: 90])
    }
}
