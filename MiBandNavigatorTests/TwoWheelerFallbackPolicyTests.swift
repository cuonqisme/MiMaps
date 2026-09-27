import XCTest
@testable import MiBandNavigator

final class TwoWheelerFallbackPolicyTests: XCTestCase {
    func testMotorcycleFallsBackOnlyForExplicitUnsupportedMode() {
        XCTAssertTrue(
            TwoWheelerFallbackPolicy.shouldFallback(
                requestedMode: .motorcycle,
                failure: .travelModeUnsupported
            )
        )
        XCTAssertFalse(
            TwoWheelerFallbackPolicy.shouldFallback(
                requestedMode: .motorcycle,
                failure: .other
            )
        )
    }

    func testCarNeverUsesMotorcycleFallback() {
        XCTAssertFalse(
            TwoWheelerFallbackPolicy.shouldFallback(
                requestedMode: .car,
                failure: .travelModeUnsupported
            )
        )
    }
}

