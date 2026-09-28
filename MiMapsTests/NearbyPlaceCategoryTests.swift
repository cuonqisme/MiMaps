import XCTest
@testable import MiMaps

final class NearbyPlaceCategoryTests: XCTestCase {
    func testEveryCategoryHasLocalizedAndEnglishFallbackQueries() {
        for category in NearbyPlaceCategory.allCases {
            XCTAssertGreaterThanOrEqual(category.fallbackSearchQueries.count, 2)
            XCTAssertTrue(category.fallbackSearchQueries.allSatisfy { !$0.isEmpty })
        }
    }

    func testFuelFallbackCoversVietnameseMapLabels() {
        XCTAssertTrue(NearbyPlaceCategory.fuel.fallbackSearchQueries.contains("trạm xăng"))
        XCTAssertTrue(NearbyPlaceCategory.fuel.fallbackSearchQueries.contains("gas station"))
    }
}
