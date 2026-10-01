import XCTest
@testable import MiMaps

@MainActor
final class MiBandManeuverIconRendererTests: XCTestCase {
    func testUsesShortRevisionedPackageToAvoidStaleBandIconCache() {
        let package = MiBandManeuverIconRenderer.packageName(for: .right)
        XCTAssertEqual(package, "com.mimaps.p3.r")
        XCTAssertLessThanOrEqual(package.utf8.count, 24)
        XCTAssertEqual(MiBandManeuverIconRenderer.maneuver(forPackageName: package), .right)
        XCTAssertEqual(
            MiBandManeuverIconRenderer.maneuver(forPackageName: "com.mimaps.nav.right"),
            .right
        )
        XCTAssertEqual(MiBandManeuverIconRenderer.packageName(for: nil), "com.mimaps")
    }

    func testRendersBandRequestedArgb8888Pixels() throws {
        let pixels = try MiBandManeuverIconRenderer.pixelData(
            maneuver: .left,
            size: 28,
            pixelFormat: 3
        )
        XCTAssertEqual(pixels.count, 28 * 28 * 4)
        XCTAssertTrue(pixels.contains { $0 != 0 })
    }

    func testRendersEveryKnownPixelFormatAtRequestedSize() throws {
        for format in [0, 1] {
            XCTAssertEqual(
                try MiBandManeuverIconRenderer.pixelData(
                    maneuver: .roundaboutExit(3),
                    size: 28,
                    pixelFormat: format
                ).count,
                28 * 28 * 2
            )
        }
        for format in [2, 3] {
            XCTAssertEqual(
                try MiBandManeuverIconRenderer.pixelData(
                    maneuver: .roundaboutExit(3),
                    size: 28,
                    pixelFormat: format
                ).count,
                28 * 28 * 4
            )
        }
        for format in [7, 8] {
            XCTAssertEqual(
                try MiBandManeuverIconRenderer.pixelData(
                    maneuver: .roundaboutExit(3),
                    size: 28,
                    pixelFormat: format
                ).count,
                28 * 28 * 3
            )
        }
    }

    func testRejectsUnsupportedPixelFormat() {
        XCTAssertThrowsError(
            try MiBandManeuverIconRenderer.pixelData(
                maneuver: .straight,
                size: 28,
                pixelFormat: 99
            )
        )
    }
}
