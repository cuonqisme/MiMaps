import XCTest
@testable import MiMaps

final class NotificationContentFactoryTests: XCTestCase {
    func testCreatesSilentNavigationNotification() {
        let content = NotificationContentFactory.make(
            symbol: "↱",
            distanceText: "120 m",
            roadName: "Trần Phú",
            soundEnabled: false
        )

        XCTAssertEqual(content.title, "↱ 120 m")
        XCTAssertEqual(content.body, "Trần Phú")
        XCTAssertEqual(content.categoryIdentifier, "NAVIGATION_MANEUVER")
        XCTAssertFalse(content.soundEnabled)
    }

    func testUsesFallbackWhenRoadNameIsMissingOrBlank() {
        let missing = NotificationContentFactory.make(
            symbol: "↑",
            distanceText: "500 m",
            roadName: nil,
            soundEnabled: true
        )
        let blank = NotificationContentFactory.make(
            symbol: "↑",
            distanceText: "500 m",
            roadName: "   ",
            soundEnabled: true
        )

        XCTAssertEqual(missing.body, "Tiếp tục theo tuyến đường")
        XCTAssertEqual(blank.body, "Tiếp tục theo tuyến đường")
        XCTAssertTrue(missing.soundEnabled)
    }
}
