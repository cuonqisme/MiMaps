import XCTest
@testable import MiBandNavigator

final class AppConfigTests: XCTestCase {
    func testAPIKeyValidatorRejectsMissingPlaceholderAndUnexpandedValues() {
        XCTAssertNil(GoogleAPIKeyValidator.normalizedKey(nil))
        XCTAssertNil(GoogleAPIKeyValidator.normalizedKey(""))
        XCTAssertNil(GoogleAPIKeyValidator.normalizedKey("   "))
        XCTAssertNil(GoogleAPIKeyValidator.normalizedKey("YOUR_GOOGLE_MAPS_API_KEY"))
        XCTAssertNil(GoogleAPIKeyValidator.normalizedKey("$(GOOGLE_MAPS_API_KEY)"))
    }

    func testAPIKeyValidatorTrimsConfiguredKey() {
        XCTAssertEqual(GoogleAPIKeyValidator.normalizedKey("  test-key  "), "test-key")
    }
}

