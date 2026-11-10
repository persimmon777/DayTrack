import XCTest
@testable import DayTrackCore

final class AppGroupCandidatesTests: XCTestCase {
    func testProfileGroupsComeFirstInStableOrder() {
        let a = AppGroupCandidates.ordered(
            profileGroups: ["group.b", "group.a"],
            declaredGroup: "group.declared",
            mainAppBundleID: "app.id"
        )
        let b = AppGroupCandidates.ordered(
            profileGroups: ["group.a", "group.b"],
            declaredGroup: "group.declared",
            mainAppBundleID: "app.id"
        )
        XCTAssertEqual(a, ["group.a", "group.b", "group.declared", "group.app.id"])
        XCTAssertEqual(a, b)
    }

    func testDuplicatesAndEmptyValuesAreDropped() {
        let result = AppGroupCandidates.ordered(
            profileGroups: ["group.app.id", ""],
            declaredGroup: "group.app.id",
            mainAppBundleID: "app.id"
        )
        XCTAssertEqual(result, ["group.app.id"])
    }

    func testWorksWithoutProfileAndBundleID() {
        let result = AppGroupCandidates.ordered(
            profileGroups: [],
            declaredGroup: "group.declared",
            mainAppBundleID: nil
        )
        XCTAssertEqual(result, ["group.declared"])
    }
}
