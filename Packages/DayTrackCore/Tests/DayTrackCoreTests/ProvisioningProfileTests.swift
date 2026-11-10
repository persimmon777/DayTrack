import XCTest
@testable import DayTrackCore

final class ProvisioningProfileTests: XCTestCase {
    /// Собирает данные, похожие на настоящий профиль: двоичная обёртка, внутри XML.
    private func profile(entitlementsXML: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Name</key>
            <string>Test Profile</string>
            <key>Entitlements</key>
            <dict>
        \(entitlementsXML)
            </dict>
        </dict>
        </plist>
        """
        var data = Data([0x30, 0x82, 0x1f, 0x00, 0xff, 0x00, 0x3c, 0x3f])
        data.append(Data(xml.utf8))
        data.append(Data([0x00, 0xa0, 0x82, 0xff, 0x3c, 0x2f]))
        return data
    }

    func testReadsAppGroupsFromWrappedProfile() {
        let data = profile(entitlementsXML: """
                <key>application-identifier</key>
                <string>ABCDE12345.app.daytrack.DayTrack.ABCDE12345</string>
                <key>com.apple.security.application-groups</key>
                <array>
                    <string>group.app.daytrack.DayTrack.ABCDE12345</string>
                </array>
        """)
        XCTAssertEqual(
            ProvisioningProfile.appGroups(fromProfileData: data),
            ["group.app.daytrack.DayTrack.ABCDE12345"]
        )
    }

    func testReadsSingleStringGroup() {
        let data = profile(entitlementsXML: """
                <key>com.apple.security.application-groups</key>
                <string>group.single</string>
        """)
        XCTAssertEqual(ProvisioningProfile.appGroups(fromProfileData: data), ["group.single"])
    }

    func testProfileWithoutGroupsGivesEmptyList() {
        let data = profile(entitlementsXML: """
                <key>get-task-allow</key>
                <true/>
        """)
        XCTAssertEqual(ProvisioningProfile.appGroups(fromProfileData: data), [])
        XCTAssertNotNil(ProvisioningProfile.entitlements(fromProfileData: data))
    }

    func testGarbageGivesEmptyList() {
        XCTAssertEqual(ProvisioningProfile.appGroups(fromProfileData: Data([1, 2, 3, 4])), [])
        XCTAssertEqual(ProvisioningProfile.appGroups(fromProfileData: Data()), [])
        XCTAssertEqual(
            ProvisioningProfile.appGroups(fromProfileData: Data("<?xml no closing tag".utf8)),
            []
        )
        XCTAssertEqual(
            ProvisioningProfile.appGroups(fromProfileData: Data("<?xml broken </plist>".utf8)),
            []
        )
    }
}
