import XCTest
@testable import MiMaps

@MainActor
final class MiBandNavigationCardRendererTests: XCTestCase {
    func testRendersBandNativeResolutionCard() throws {
        let instruction = NavigationInstruction(
            maneuver: .roundaboutExit(3),
            roadName: "Giáp Hải",
            distanceToManeuverMeters: 513,
            remainingDistanceMeters: 9_700,
            remainingTimeSeconds: 1_200,
            stepIdentifier: "roundabout",
            timestamp: Date(timeIntervalSince1970: 1_000)
        )

        let image = MiBandNavigationCardRenderer.render(instruction)
        XCTAssertEqual(image.size, MiBandNavigationCardRenderer.canvasSize)
        XCTAssertEqual(image.scale, 1)
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 1_000)
    }

    func testRendersEveryManeuverWithoutMissingSymbol() {
        let maneuvers: [NavigationManeuver] = [
            .straight, .slightLeft, .left, .sharpLeft,
            .slightRight, .right, .sharpRight,
            .uTurnLeft, .uTurnRight,
            .mergeLeft, .mergeRight, .forkLeft, .forkRight,
            .rampLeft, .rampRight, .roundabout, .roundaboutExit(2),
            .destination, .unknown
        ]

        for maneuver in maneuvers {
            let instruction = NavigationInstruction(
                maneuver: maneuver,
                roadName: "MiMaps",
                distanceToManeuverMeters: 100,
                remainingDistanceMeters: 1_000,
                remainingTimeSeconds: 120,
                stepIdentifier: "\(maneuver)"
            )
            XCTAssertNotNil(MiBandNavigationCardRenderer.pngData(instruction))
        }
    }
}
