import XCTest
@testable import MiMaps

final class MiBandWatchfaceInstallationTests: XCTestCase {
    func testSafetyGateRequiresRestoreTargetBatteryFirmwareAndAcknowledgement() throws {
        let valid = MiBandWatchfaceSafetySnapshot(
            isConnectedAndAuthenticated: true,
            firmwareVersion: "2.3.14",
            batteryLevel: 80,
            previousWatchfaceIdentifier: "266240005",
            hasValidatedPackage: true,
            riskAcknowledged: true
        )
        XCTAssertNoThrow(try valid.validate())

        XCTAssertThrowsError(
            try MiBandWatchfaceSafetySnapshot(
                isConnectedAndAuthenticated: true,
                firmwareVersion: "2.3.14",
                batteryLevel: 29,
                previousWatchfaceIdentifier: "266240005",
                hasValidatedPackage: true,
                riskAcknowledged: true
            ).validate()
        ) {
            XCTAssertEqual($0 as? MiBandWatchfaceSafetyError, .batteryTooLow(29))
        }

        XCTAssertThrowsError(
            try MiBandWatchfaceSafetySnapshot(
                isConnectedAndAuthenticated: true,
                firmwareVersion: "2.3.14",
                batteryLevel: 80,
                previousWatchfaceIdentifier: nil,
                hasValidatedPackage: true,
                riskAcknowledged: true
            ).validate()
        ) {
            XCTAssertEqual($0 as? MiBandWatchfaceSafetyError, .activeWatchfaceUnknown)
        }
    }

    func testRealtimePolicyCoalescesSmallFrequentChangesButNeverAChangedStep() {
        let policy = MiBandWatchfaceRealtimePolicy(
            minimumInterval: 5,
            minimumDistanceChangeMeters: 5
        )
        let start = Date(timeIntervalSince1970: 100)
        let previous = instruction(distance: 100, step: "a", timestamp: start)

        XCTAssertFalse(
            policy.shouldBuild(
                previousTimestamp: start,
                previousInstruction: previous,
                next: instruction(distance: 94, step: "a", timestamp: start.addingTimeInterval(2))
            )
        )
        XCTAssertTrue(
            policy.shouldBuild(
                previousTimestamp: start,
                previousInstruction: previous,
                next: instruction(distance: 94, step: "a", timestamp: start.addingTimeInterval(5))
            )
        )
        XCTAssertTrue(
            policy.shouldBuild(
                previousTimestamp: start,
                previousInstruction: previous,
                next: instruction(distance: 99, step: "b", timestamp: start.addingTimeInterval(1))
            )
        )
    }

    private func instruction(distance: Double, step: String, timestamp: Date) -> NavigationInstruction {
        NavigationInstruction(
            maneuver: .left,
            roadName: "Quang Trung",
            distanceToManeuverMeters: distance,
            remainingDistanceMeters: 1_000,
            remainingTimeSeconds: 600,
            stepIdentifier: step,
            timestamp: timestamp
        )
    }
}
