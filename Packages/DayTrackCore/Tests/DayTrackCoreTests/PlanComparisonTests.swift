import XCTest
@testable import DayTrackCore

final class PlanComparisonTests: XCTestCase {
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        TestTime.date(2026, 11, 10, hour, minute)
    }

    private let math = UUID()
    private let essay = UUID()
    private let english = UUID()

    func testFullPartialMissedAndPending() {
        let plan = [
            PlanSlot(id: math, start: at(9), end: at(10, 30)),
            PlanSlot(id: essay, start: at(11), end: at(13)),
            PlanSlot(id: english, start: at(15), end: at(16, 30)),
            PlanSlot(id: UUID(), start: at(20), end: at(21)),
        ]
        let facts = [
            FactSlot(id: UUID(), planID: math, start: at(9), end: at(10, 30)),
            FactSlot(id: UUID(), planID: essay, start: at(12, 10), end: at(13)),
            FactSlot(id: UUID(), planID: nil, start: at(14, 10), end: at(16)),
        ]
        let result = PlanComparison.evaluate(plan: plan, facts: facts, now: at(18))

        XCTAssertEqual(result.blocks.map(\.status), [.done, .partial, .missed, .pending])
        XCTAssertEqual(result.plannedMinutes, 90 + 120 + 90 + 60)
        XCTAssertEqual(result.creditedMinutes, 90 + 50)
        XCTAssertEqual(result.unplannedMinutes, 110)
        XCTAssertEqual(result.completion ?? 0, 140.0 / 360.0, accuracy: 0.0001)
        XCTAssertEqual(result.count(of: .missed), 1)
    }

    func testOvertimeIsNotCreditedAbovePlan() {
        let plan = [PlanSlot(id: math, start: at(9), end: at(10))]
        let facts = [FactSlot(id: UUID(), planID: math, start: at(9), end: at(11))]
        let result = PlanComparison.evaluate(plan: plan, facts: facts, now: at(12))

        XCTAssertEqual(result.blocks[0].factMinutes, 120)
        XCTAssertEqual(result.blocks[0].creditedMinutes, 60)
        XCTAssertEqual(result.completion, 1)
    }

    func testSeveralFactsForOneBlockAddUp() {
        let plan = [PlanSlot(id: essay, start: at(11), end: at(13))]
        let facts = [
            FactSlot(id: UUID(), planID: essay, start: at(11, 5), end: at(12)),
            FactSlot(id: UUID(), planID: essay, start: at(17), end: at(18)),
        ]
        let block = PlanComparison.evaluate(plan: plan, facts: facts, now: at(19)).blocks[0]

        XCTAssertEqual(block.factMinutes, 115)
        XCTAssertEqual(block.status, .done)
        XCTAssertEqual(block.startShiftMinutes, 5)
        XCTAssertFalse(block.isShifted)
    }

    func testNinetyPercentCountsAsDone() {
        let plan = [PlanSlot(id: math, start: at(9), end: at(10, 40))]
        let done = PlanComparison.evaluate(
            plan: plan,
            facts: [FactSlot(id: UUID(), planID: math, start: at(9), end: at(10, 30))],
            now: at(12)
        )
        let partial = PlanComparison.evaluate(
            plan: plan,
            facts: [FactSlot(id: UUID(), planID: math, start: at(9), end: at(10, 29))],
            now: at(12)
        )
        XCTAssertEqual(done.blocks[0].status, .done)
        XCTAssertEqual(partial.blocks[0].status, .partial)
    }

    func testShiftIsFlaggedBeyondThreshold() {
        let plan = [PlanSlot(id: math, start: at(9), end: at(10))]
        let late = PlanComparison.evaluate(
            plan: plan,
            facts: [FactSlot(id: UUID(), planID: math, start: at(9, 40), end: at(10, 40))],
            now: at(12)
        ).blocks[0]
        let early = PlanComparison.evaluate(
            plan: plan,
            facts: [FactSlot(id: UUID(), planID: math, start: at(8, 30), end: at(9, 30))],
            now: at(12)
        ).blocks[0]

        XCTAssertEqual(late.startShiftMinutes, 40)
        XCTAssertTrue(late.isShifted)
        XCTAssertEqual(early.startShiftMinutes, -30)
        XCTAssertTrue(early.isShifted)
    }

    func testMarkedMissedBeforeItsTimeAndFactOverridesMark() {
        let plan = [PlanSlot(id: math, start: at(20), end: at(21), markedMissed: true)]
        let missed = PlanComparison.evaluate(plan: plan, facts: [], now: at(12))
        XCTAssertEqual(missed.blocks[0].status, .missed)

        let withFact = PlanComparison.evaluate(
            plan: plan,
            facts: [FactSlot(id: UUID(), planID: math, start: at(20), end: at(21))],
            now: at(22)
        )
        XCTAssertEqual(withFact.blocks[0].status, .done)
    }

    func testFactLinkedToAbsentBlockIsUnplanned() {
        let result = PlanComparison.evaluate(
            plan: [],
            facts: [FactSlot(id: UUID(), planID: UUID(), start: at(9), end: at(10))],
            now: at(12)
        )
        XCTAssertEqual(result.unplannedMinutes, 60)
        XCTAssertNil(result.completion)
    }
}
