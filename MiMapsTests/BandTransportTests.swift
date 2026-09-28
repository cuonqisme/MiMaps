import XCTest
@testable import MiMaps

@MainActor
final class BandTransportTests: XCTestCase {
    func testTransportRequiresStart() async {
        let transport = NotificationBandTransport(scheduler: BandSchedulerSpy())

        do {
            try await transport.send(instruction(step: "one", distance: 200))
            XCTFail("Expected notStarted")
        } catch {
            XCTAssertEqual(error as? BandTransportError, .notStarted)
        }
    }

    func testTransportFormatsSchedulesAndDeduplicates() async throws {
        let scheduler = BandSchedulerSpy()
        let transport = NotificationBandTransport(
            scheduler: scheduler,
            notificationsEnabled: { true },
            soundEnabled: { true }
        )
        let value = instruction(step: "one", distance: 200)

        try await transport.start()
        try await transport.send(value)
        try await transport.send(value)

        XCTAssertEqual(scheduler.contents.count, 1)
        XCTAssertEqual(scheduler.contents.first?.title, "→ 200 m")
        XCTAssertEqual(scheduler.contents.first?.soundEnabled, true)
    }

    func testTransportHonorsNotificationToggle() async throws {
        let scheduler = BandSchedulerSpy()
        let transport = NotificationBandTransport(
            scheduler: scheduler,
            notificationsEnabled: { false }
        )

        try await transport.start()
        try await transport.send(instruction(step: "one", distance: 80))

        XCTAssertTrue(scheduler.contents.isEmpty)
    }

    func testDeduplicatorResetsForNewStep() {
        var deduplicator = BandInstructionDeduplicator()
        let first = instruction(step: "one", distance: 80)
        let next = instruction(step: "two", distance: 80)

        XCTAssertTrue(deduplicator.shouldSend(first))
        XCTAssertFalse(deduplicator.shouldSend(first))
        XCTAssertTrue(deduplicator.shouldSend(next))
    }
}

@MainActor
private final class BandSchedulerSpy: LocalNotificationScheduling {
    private(set) var contents: [NavigationNotificationContent] = []

    func schedule(_ content: NavigationNotificationContent) async throws {
        contents.append(content)
    }
}

private func instruction(step: String, distance: Double) -> NavigationInstruction {
    NavigationInstruction(
        maneuver: .right,
        roadName: "Trần Phú",
        distanceToManeuverMeters: distance,
        remainingDistanceMeters: 1_000,
        remainingTimeSeconds: 120,
        stepIdentifier: step,
        timestamp: Date(timeIntervalSince1970: 1_000)
    )
}
