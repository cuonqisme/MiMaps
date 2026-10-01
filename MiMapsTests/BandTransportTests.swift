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

    func testTransportHonorsSpeedLimitToggle() async throws {
        let scheduler = BandSchedulerSpy()
        let transport = NotificationBandTransport(
            scheduler: scheduler,
            speedLimitEnabled: { false }
        )
        let value = NavigationInstruction(
            maneuver: .right,
            roadName: "Trần Phú",
            distanceToManeuverMeters: 143,
            remainingDistanceMeters: 1_000,
            remainingTimeSeconds: 120,
            stepIdentifier: "limit",
            speedLimitKPH: 60
        )

        try await transport.start()
        try await transport.send(value)

        XCTAssertEqual(scheduler.contents.first?.body, "Rẽ phải · Trần Phú")
    }

    func testTransportUsesConfiguredRouteCardStyle() async throws {
        let scheduler = BandSchedulerSpy()
        let transport = NotificationBandTransport(
            scheduler: scheduler,
            displayStyle: { .routeCard }
        )

        try await transport.start()
        try await transport.send(instruction(step: "card", distance: 200))

        XCTAssertTrue(scheduler.contents.first?.body.contains("\n2 phút · 1 km · đến ") == true)
    }

    func testDirectTransportMirrorsInstructionToAuthenticatedBand() async throws {
        let scheduler = BandSchedulerSpy()
        let sender = DirectSenderSpy(canSend: true)
        let transport = DirectMiBandTransport(
            scheduler: scheduler,
            directSender: sender
        )

        try await transport.start()
        try await transport.send(instruction(step: "direct", distance: 100))

        XCTAssertEqual(scheduler.contents.count, 1)
        XCTAssertEqual(sender.messages.count, 1)
        XCTAssertEqual(sender.messages.first?.title, "→ 100 m")
        XCTAssertEqual(sender.messages.first?.body, "Rẽ phải · Trần Phú")
    }

    func testDirectTransportKeepsPhoneNotificationWhenBandIsUnavailable() async throws {
        let scheduler = BandSchedulerSpy()
        let sender = DirectSenderSpy(canSend: false)
        let transport = DirectMiBandTransport(
            scheduler: scheduler,
            directSender: sender
        )

        try await transport.start()
        try await transport.send(instruction(step: "phone-only", distance: 100))

        XCTAssertEqual(scheduler.contents.count, 1)
        XCTAssertTrue(sender.messages.isEmpty)
    }

    func testDirectTransportDoesNotDependOnPhoneNotificationPermission() async throws {
        let sender = DirectSenderSpy(canSend: true)
        let transport = DirectMiBandTransport(
            scheduler: FailingBandScheduler(),
            directSender: sender
        )

        try await transport.start()
        try await transport.send(instruction(step: "ble-only", distance: 80))

        XCTAssertEqual(sender.messages.count, 1)
    }

    func testDirectTransportThrottlesRealtimeDistanceUpdatesWithoutPhoneNotifications() async throws {
        let scheduler = BandSchedulerSpy()
        let sender = DirectSenderSpy(canSend: true)
        let transport = DirectMiBandTransport(
            scheduler: scheduler,
            directSender: sender,
            liveUpdatesEnabled: { true }
        )

        try await transport.start()
        try await transport.updateLive(instruction(
            step: "live",
            distance: 100,
            timestamp: Date(timeIntervalSince1970: 1_000)
        ))
        try await transport.updateLive(instruction(
            step: "live",
            distance: 98,
            timestamp: Date(timeIntervalSince1970: 1_003)
        ))
        try await transport.updateLive(instruction(
            step: "live",
            distance: 90,
            timestamp: Date(timeIntervalSince1970: 1_006)
        ))

        XCTAssertEqual(sender.messages.count, 2)
        XCTAssertTrue(scheduler.contents.isEmpty)
        XCTAssertEqual(sender.messages.last?.title, "→ 90 m")
    }

    func testPolicyNotificationDoesNotDuplicateIdenticalRealtimeBandUpdate() async throws {
        let scheduler = BandSchedulerSpy()
        let sender = DirectSenderSpy(canSend: true)
        let transport = DirectMiBandTransport(
            scheduler: scheduler,
            directSender: sender,
            liveUpdatesEnabled: { true }
        )
        let value = instruction(step: "same", distance: 80)

        try await transport.start()
        try await transport.updateLive(value)
        try await transport.send(value)

        XCTAssertEqual(sender.messages.count, 1)
        XCTAssertEqual(scheduler.contents.count, 1)
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

@MainActor
private final class FailingBandScheduler: LocalNotificationScheduling {
    func schedule(_ content: NavigationNotificationContent) async throws {
        throw LocalNotificationError.permissionDenied
    }
}

@MainActor
private final class DirectSenderSpy: MiBandDirectNotificationSending {
    struct Message: Equatable {
        let title: String
        let body: String
        let label: String
    }

    let canSendDirectNotifications: Bool
    private(set) var messages: [Message] = []

    init(canSend: Bool) {
        canSendDirectNotifications = canSend
    }

    func sendDirectNotification(
        title: String,
        body: String,
        label: String,
        maneuver: NavigationManeuver?
    ) {
        messages.append(Message(title: title, body: body, label: label))
    }
}

private func instruction(
    step: String,
    distance: Double,
    timestamp: Date = Date(timeIntervalSince1970: 1_000)
) -> NavigationInstruction {
    NavigationInstruction(
        maneuver: .right,
        roadName: "Trần Phú",
        distanceToManeuverMeters: distance,
        remainingDistanceMeters: 1_000,
        remainingTimeSeconds: 120,
        stepIdentifier: step,
        timestamp: timestamp
    )
}
