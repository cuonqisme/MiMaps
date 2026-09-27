import XCTest
@testable import MiBandNavigator

final class GoogleNavigationInstructionFactoryTests: XCTestCase {
    func testBuildsProviderNeutralInstructionFromFeedSnapshot() {
        let timestamp = Date(timeIntervalSince1970: 1_234)
        let snapshot = GoogleNavigationFeedSnapshot(
            maneuverRawValue: 54,
            roundaboutTurnNumber: 2,
            routeRevision: 3,
            stepNumber: 7,
            roadName: "  Trần Phú  ",
            distanceToManeuverMeters: 120,
            remainingDistanceMeters: 5_800,
            remainingTimeSeconds: 720
        )

        let instruction = GoogleNavigationInstructionFactory().makeInstruction(
            from: snapshot,
            timestamp: timestamp
        )

        XCTAssertEqual(instruction.maneuver, .roundaboutExit(2))
        XCTAssertEqual(instruction.roadName, "Trần Phú")
        XCTAssertEqual(instruction.distanceToManeuverMeters, 120)
        XCTAssertEqual(instruction.remainingDistanceMeters, 5_800)
        XCTAssertEqual(instruction.remainingTimeSeconds, 720)
        XCTAssertEqual(instruction.stepIdentifier, "google-route-3-step-7")
        XCTAssertEqual(instruction.timestamp, timestamp)
    }

    func testNormalizesMissingRoadAndNegativeMetrics() {
        let snapshot = GoogleNavigationFeedSnapshot(
            maneuverRawValue: 0,
            roundaboutTurnNumber: -1,
            routeRevision: 0,
            stepNumber: 0,
            roadName: "  ",
            distanceToManeuverMeters: -1,
            remainingDistanceMeters: -2,
            remainingTimeSeconds: -3
        )

        let instruction = GoogleNavigationInstructionFactory().makeInstruction(from: snapshot)

        XCTAssertEqual(instruction.maneuver, .unknown)
        XCTAssertNil(instruction.roadName)
        XCTAssertEqual(instruction.distanceToManeuverMeters, 0)
        XCTAssertEqual(instruction.remainingDistanceMeters, 0)
        XCTAssertEqual(instruction.remainingTimeSeconds, 0)
    }
}
