import XCTest
@testable import MiMaps

final class MiBandNotificationIconCacheTests: XCTestCase {
    func testCachePersistsPerBandAndDeduplicatesPackages() throws {
        let suite = "MiBandNotificationIconCacheTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = MiBandNotificationIconCache(defaults: defaults)
        let firstBand = UUID()
        let secondBand = UUID()

        XCTAssertFalse(cache.contains(package: "com.mimaps.p4.l", deviceIdentifier: firstBand))
        cache.insert(package: "com.mimaps.p4.l", deviceIdentifier: firstBand)
        cache.insert(package: "com.mimaps.p4.l", deviceIdentifier: firstBand)

        XCTAssertTrue(cache.contains(package: "com.mimaps.p4.l", deviceIdentifier: firstBand))
        XCTAssertFalse(cache.contains(package: "com.mimaps.p4.l", deviceIdentifier: secondBand))
        XCTAssertFalse(cache.contains(package: "com.mimaps.p4.r", deviceIdentifier: firstBand))

        let reloaded = MiBandNotificationIconCache(defaults: defaults)
        XCTAssertTrue(reloaded.contains(package: "com.mimaps.p4.l", deviceIdentifier: firstBand))

        reloaded.removeAll(deviceIdentifier: firstBand)
        XCTAssertFalse(reloaded.contains(package: "com.mimaps.p4.l", deviceIdentifier: firstBand))
    }

    func testCacheDoesNotStoreWithoutDeviceIdentifier() throws {
        let suite = "MiBandNotificationIconCacheTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = MiBandNotificationIconCache(defaults: defaults)
        cache.insert(package: "com.mimaps.p4.l", deviceIdentifier: nil)

        XCTAssertFalse(cache.contains(package: "com.mimaps.p4.l", deviceIdentifier: nil))
    }
}
