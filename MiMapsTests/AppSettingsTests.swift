import Foundation
import XCTest
@testable import MiMaps

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
        XCTAssertTrue(initial.showTraffic)
        XCTAssertTrue(initial.recentDestinations.isEmpty)
        XCTAssertEqual(initial.routePreferences, .standard)

        initial.farThresholdMeters = 750
        initial.mediumThresholdMeters = 250
        initial.nearThresholdMeters = 90
        initial.immediateThresholdMeters = 25
        initial.travelMode = .transit
        initial.mapDisplayStyle = .hybrid
        initial.showTraffic = false
        initial.avoidTolls = true
        initial.avoidHighways = true
        for index in 0..<10 {
            initial.recordRecentDestination(
                Destination(
                    displayName: "Điểm \(index)",
                    latitude: 21 + Double(index) / 1_000,
                    longitude: 105
                )
            )
        }

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.notificationThresholds, [750, 250, 90, 25])
        XCTAssertEqual(reloaded.travelMode, .transit)
        XCTAssertEqual(reloaded.mapDisplayStyle, .hybrid)
        XCTAssertFalse(reloaded.showTraffic)
        XCTAssertEqual(reloaded.recentDestinations.count, 8)
        XCTAssertEqual(reloaded.recentDestinations.first?.displayName, "Điểm 9")
        XCTAssertEqual(
            reloaded.routePreferences,
            RoutePreferences(avoidTolls: true, avoidHighways: true)
        )

        reloaded.clearRecentDestinations()
        XCTAssertTrue(AppSettings(defaults: defaults).recentDestinations.isEmpty)
    }
}
