import XCTest
@testable import MiMaps

final class BandNotificationPolicyTests: XCTestCase {
    func test510To499Crosses500() {
        var policy = BandNotificationPolicy()
        _ = policy.evaluate(instruction(distance: 510, time: 0))

        let decision = policy.evaluate(instruction(distance: 499, time: 3))

        XCTAssertEqual(decision.crossedThresholds, [500])
        XCTAssertEqual(decision.notification?.distanceToManeuverMeters, 500)
    }

    func test501To480Crosses500() {
        var policy = BandNotificationPolicy()
        _ = policy.evaluate(instruction(distance: 501, time: 0))

        XCTAssertEqual(policy.evaluate(instruction(distance: 480, time: 3)).crossedThresholds, [500])
    }

    func test510To199Batches500And200IntoNearestAlert() {
        var policy = BandNotificationPolicy()
        _ = policy.evaluate(instruction(distance: 510, time: 0))

        let decision = policy.evaluate(instruction(distance: 199, time: 3))

        XCTAssertEqual(decision.crossedThresholds, [500, 200])
        XCTAssertEqual(decision.notification?.distanceToManeuverMeters, 200)
        XCTAssertEqual(policy.firedThresholds, [500, 200])
    }

    func testExactRequiredThresholdJumps() {
        var policy200 = BandNotificationPolicy()
        _ = policy200.evaluate(instruction(distance: 201, time: 0))
        XCTAssertEqual(policy200.evaluate(instruction(distance: 199, time: 3)).crossedThresholds, [200])

        var policy80 = BandNotificationPolicy()
        _ = policy80.evaluate(instruction(distance: 85, time: 0))
        XCTAssertEqual(policy80.evaluate(instruction(distance: 78, time: 3)).crossedThresholds, [80])

        var policy30 = BandNotificationPolicy()
        _ = policy30.evaluate(instruction(distance: 31, time: 0))
        XCTAssertEqual(policy30.evaluate(instruction(distance: 29, time: 3)).crossedThresholds, [30])
    }

    func testThresholdIsNotSentTwice() {
        var policy = BandNotificationPolicy()
        _ = policy.evaluate(instruction(distance: 201, time: 0))
        _ = policy.evaluate(instruction(distance: 199, time: 3))

        let decision = policy.evaluate(instruction(distance: 190, time: 6))

        XCTAssertNil(decision.notification)
        XCTAssertFalse(decision.crossedThresholds.contains(200))
    }

    func testCooldownDefersButDoesNotLoseCrossedThreshold() {
        var policy = BandNotificationPolicy(cooldownSeconds: 2)
        _ = policy.evaluate(instruction(distance: 510, time: 0))
        _ = policy.evaluate(instruction(distance: 499, time: 3))

        let deferred = policy.evaluate(instruction(distance: 199, time: 4))
        let delivered = policy.evaluate(instruction(distance: 190, time: 6))

        XCTAssertEqual(deferred.reason, .cooldown)
        XCTAssertNil(deferred.notification)
        XCTAssertEqual(deferred.crossedThresholds, [200])
        XCTAssertEqual(delivered.notification?.distanceToManeuverMeters, 200)
        XCTAssertTrue(policy.pendingThresholds.isEmpty)
    }

    func testNewManeuverResetsThresholdsAndBypassesCooldown() {
        var policy = BandNotificationPolicy(cooldownSeconds: 30)
        _ = policy.evaluate(instruction(distance: 510, step: "one", time: 0))
        _ = policy.evaluate(instruction(distance: 499, step: "one", time: 1))

        let next = policy.evaluate(instruction(distance: 500, step: "two", time: 2))

        XCTAssertEqual(next.notification?.stepIdentifier, "two")
        XCTAssertEqual(next.crossedThresholds, [500])
        XCTAssertEqual(policy.firedThresholds, [500])
    }

    func testFirstLiveUpdateUsesNearestApplicableThreshold() {
        var policy = BandNotificationPolicy()

        let at450 = policy.evaluate(instruction(distance: 450, step: "one", time: 0))
        let at150 = policy.evaluate(instruction(distance: 150, step: "two", time: 1))

        XCTAssertEqual(at450.notification?.distanceToManeuverMeters, 500)
        XCTAssertEqual(at450.crossedThresholds, [500])
        XCTAssertEqual(at150.notification?.distanceToManeuverMeters, 200)
        XCTAssertEqual(at150.crossedThresholds, [500, 200])
    }

    func testArrivalIsSentOnlyOnce() {
        var policy = BandNotificationPolicy()
        let arrival = instruction(distance: 0, maneuver: .destination, time: 1)

        XCTAssertEqual(policy.evaluate(arrival).reason, .arrival)
        XCTAssertEqual(policy.evaluate(arrival).reason, .duplicateArrival)
    }

    func testSafetyAlertIsSentImmediatelyAndOnlyOnce() {
        var policy = BandNotificationPolicy()
        let alert = NavigationSafetyAlert(
            identifier: "camera-1",
            kind: .fixedSpeedCamera,
            distanceMeters: 500
        )
        let item = NavigationInstruction(
            maneuver: .straight,
            roadName: nil,
            distanceToManeuverMeters: 1_000,
            remainingDistanceMeters: 3_000,
            remainingTimeSeconds: 300,
            stepIdentifier: "step",
            safetyAlert: alert
        )

        XCTAssertEqual(policy.evaluate(item).reason, .safetyAlert)
        XCTAssertEqual(policy.evaluate(item).reason, .duplicateSafetyAlert)
    }

    private func instruction(
        distance: Double,
        maneuver: NavigationManeuver = .right,
        step: String = "step",
        time: TimeInterval
    ) -> NavigationInstruction {
        NavigationInstruction(
            maneuver: maneuver,
            roadName: "Trần Phú",
            distanceToManeuverMeters: distance,
            remainingDistanceMeters: 3_000,
            remainingTimeSeconds: 300,
            stepIdentifier: step,
            timestamp: Date(timeIntervalSince1970: time)
        )
    }
}
