import Foundation
import XCTest
@testable import MiBandNavigator

@MainActor
final class AppSettingsTests: XCTestCase {
    func testNotificationThresholdsUseDefaultsAndPersistOverrides() {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initial = AppSettings(defaults: defaults)
        XCTAssertEqual(initial.notificationThresholds, [500, 200, 80, 30])
        XCTAssertEqual(initial.travelMode, .motorcycle)
        XCTAssertEqual(initial.mapDisplayStyle, .standard)
        XCTAssertEqual(initial.routePreferences, .standard)

        initial.farThresholdMeters = 750
        initial.mediumThresholdMeters = 250
        initial.nearThresholdMeters = 90
        initial.immediateThresholdMeters = 25
        initial.travelMode = .transit
        initial.mapDisplayStyle = .hybrid
        initial.avoidTolls = true
        initial.avoidHighways = true

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.notificationThresholds, [750, 250, 90, 25])
        XCTAssertEqual(reloaded.travelMode, .transit)
        XCTAssertEqual(reloaded.mapDisplayStyle, .hybrid)
        XCTAssertEqual(
            reloaded.routePreferences,
            RoutePreferences(avoidTolls: true, avoidHighways: true)
        )
    }
}
