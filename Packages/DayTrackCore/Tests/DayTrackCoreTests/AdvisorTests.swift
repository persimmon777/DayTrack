import XCTest
@testable import DayTrackCore

final class AdvisorTests: XCTestCase {
    private let calendar = TestTime.calendar()
    private func at(_ hour: Int, _ minute: Int = 0) -> Date { TestTime.date(2026, 11, 16, hour, minute) }
    private var window: DateInterval { DateInterval(start: at(0), end: TestTime.date(2026, 11, 17)) }

    private func block(_ title: String, _ from: Int, _ to: Int, _ kind: CategoryKind,
                       category: String? = nil, frog: Bool = false, fact: Bool = false) -> AdvisorBlock {
        AdvisorBlock(id: UUID(), title: title, start: at(from), end: at(to), kind: kind,
                     categoryID: category, categoryName: category, isFrog: frog, hasFact: fact)
    }

    private func rules(_ input: AdvisorInput, _ settings: AdvisorSettings = AdvisorSettings()) -> [AdviceRule] {
        Advisor.advise(input, settings: settings, calendar: calendar).map(\.rule)
    }

    func testFrogSuggestsLongestStudyBlock() {
        let long = block("Курсовая", 11, 14, .study)
        let input = AdvisorInput(blocks: [block("Матан", 9, 10, .study), long], dayWindow: window, now: at(7))
        let advice = Advisor.frog(input)
        XCTAssertEqual(advice?.action, .markFrog(long.id))
    }

    func testFrogPlacedLateIsFlaggedWithoutAction() {
        let input = AdvisorInput(blocks: [block("Матан", 9, 10, .study), block("Курсовая", 15, 17, .study, frog: true)],
                                 dayWindow: window, now: at(7))
        XCTAssertNotNil(Advisor.frog(input))
        XCTAssertNil(Advisor.frog(input)?.action)
    }

    func testStartSmallOnlyWhenFrogOverdueWithoutFact() {
        let frog = block("Курсовая", 9, 11, .study, frog: true)
        XCTAssertNotNil(Advisor.startSmall(AdvisorInput(blocks: [frog], dayWindow: window, now: at(12)), calendar: calendar))
        XCTAssertNil(Advisor.startSmall(AdvisorInput(blocks: [frog], dayWindow: window, now: at(8)), calendar: calendar))
        var done = frog
        done.hasFact = true
        XCTAssertNil(Advisor.startSmall(AdvisorInput(blocks: [done], dayWindow: window, now: at(12)), calendar: calendar))
    }

    func testEstimatesNeedEnoughSamples() {
        let blocks = [block("Матан", 9, 10, .study, category: "math")]
        let few = AdvisorInput(blocks: blocks, dayWindow: window, now: at(7), estimateHistory: ["math": (1.5, 2)])
        let many = AdvisorInput(blocks: blocks, dayWindow: window, now: at(7), estimateHistory: ["math": (1.3, 5)])
        XCTAssertNil(Advisor.estimates(few))
        XCTAssertEqual(Advisor.estimates(many)?.action, .extendCategory("math", ratio: 1.3))
    }

    func testLoadAndOneThreeFive() {
        let busy = (8..<20).map { block("Дело \($0)", $0, $0 + 1, .study) }
        let input = AdvisorInput(blocks: busy, dayWindow: window, now: at(7), awakeMinutes: 16 * 60)
        XCTAssertNotNil(Advisor.load(input, AdvisorSettings()))
        XCTAssertNotNil(Advisor.oneThreeFive(input))
        let light = AdvisorInput(blocks: [block("Матан", 9, 10, .study)], dayWindow: window, now: at(7))
        XCTAssertNil(Advisor.load(light, AdvisorSettings()))
        XCTAssertNil(Advisor.oneThreeFive(light))
    }

    func testBufferFindsFreeSlotAndRespectsExistingBuffer() {
        let blocks = [block("Пары", 9, 13, .study), block("Курсовая", 14, 16, .study)]
        let advice = Advisor.buffer(AdvisorInput(blocks: blocks, dayWindow: window, now: at(7)), AdvisorSettings())
        guard case .addBlock(_, _, let start, let minutes)? = advice?.action else { return XCTFail("нет действия") }
        XCTAssertEqual(start, at(13))
        XCTAssertEqual(minutes, 60)

        let withBuffer = blocks + [block("Резерв", 17, 18, .other)]
        XCTAssertNil(Advisor.buffer(AdvisorInput(blocks: withBuffer, dayWindow: window, now: at(7)), AdvisorSettings()))
    }

    func testFreeSlotStartsAfterNow() {
        let input = AdvisorInput(blocks: [], dayWindow: window, now: at(15, 10))
        XCTAssertEqual(Advisor.freeSlot(input, minutes: 30), at(15, 15))
    }

    func testRestBreaksSleepCeiling() {
        let blocks = [block("Пары", 9, 13, .study), block("Сон", 0, 6, .sleep)]
        let input = AdvisorInput(blocks: blocks, dayWindow: window, now: at(7))
        let found = rules(input, AdvisorSettings(studyCeilingMinutes: 3 * 60))
        XCTAssertTrue(found.contains(.rest))
        XCTAssertTrue(found.contains(.breaks))
        XCTAssertTrue(found.contains(.sleep))
        XCTAssertTrue(found.contains(.studyCeiling))
    }

    func testDisabledRulesAreSkipped() {
        let input = AdvisorInput(blocks: [block("Пары", 9, 13, .study)], dayWindow: window, now: at(7))
        XCTAssertFalse(rules(input, AdvisorSettings(disabled: [.rest])).contains(.rest))
    }

    func testMinimumDayAfterTwoEmptyDays() {
        XCTAssertNotNil(Advisor.minimumDay(AdvisorInput(blocks: [], dayWindow: window, now: at(10), daysWithoutPlan: 2)))
        XCTAssertNil(Advisor.minimumDay(AdvisorInput(blocks: [], dayWindow: window, now: at(10), daysWithoutPlan: 1)))
    }

    func testEnergyAndWeekBalance() {
        let blocks = [block("Курсовая", 20, 22, .study, frog: true)]
        XCTAssertNotNil(Advisor.energy(AdvisorInput(blocks: blocks, dayWindow: window, now: at(7), bestEnergyHours: [10, 11]), calendar: calendar))
        XCTAssertNil(Advisor.energy(AdvisorInput(blocks: blocks, dayWindow: window, now: at(7), bestEnergyHours: [20]), calendar: calendar))

        let low = AdvisorInput(blocks: [], dayWindow: window, now: at(7), weekStudyMinutes: 300, weekDaysElapsed: 4)
        XCTAssertNotNil(Advisor.weekBalance(low, AdvisorSettings()))
        let normal = AdvisorInput(blocks: [], dayWindow: window, now: at(7), weekStudyMinutes: 1400, weekDaysElapsed: 4)
        XCTAssertNil(Advisor.weekBalance(normal, AdvisorSettings()))
    }
}
