import XCTest
@testable import MiMaps

@MainActor
final class LiveNavigationPipelineTests: XCTestCase {
    func testProviderFeedCreatesThresholdAndArrivalNotificationsWithoutDuplicates() async {
        let provider = ControllableNavigationProvider()
        let scheduler = LivePipelineSchedulerSpy()
        let transport = NotificationBandTransport(
            scheduler: scheduler,
            notificationsEnabled: { true },
            soundEnabled: { false }
        )
        let coordinator = NavigationCoordinator(
            provider: provider,
            bandTransport: transport,
            notificationPolicy: BandNotificationPolicy(cooldownSeconds: 0)
        )

        await coordinator.calculateRoute(to: destination, travelMode: .motorcycle)
        await coordinator.startNavigation()
        provider.emit(instruction(distance: 510, timestamp: 0))
        provider.emit(instruction(distance: 499, timestamp: 1))
        await waitUntil { scheduler.contents.count == 1 }

        provider.emit(instruction(distance: 190, timestamp: 2))
        await waitUntil { scheduler.contents.count == 2 }

        let arrival = instruction(
            distance: 0,
            maneuver: .destination,
            step: "arrival",
            timestamp: 3
        )
        provider.emit(arrival)
        provider.emit(arrival)
        await waitUntil { scheduler.contents.count == 3 }

        XCTAssertEqual(scheduler.contents.map(\.title), ["→ 500 m", "→ 200 m", "● Đã đến nơi"])
        XCTAssertEqual(coordinator.lastBandNotification?.maneuver, .destination)
        XCTAssertEqual(coordinator.firedThresholds, [])
    }

    private var destination: Destination {
        Destination(displayName: "Test", latitude: 21, longitude: 105)
    }

    private func instruction(
        distance: Double,
        maneuver: NavigationManeuver = .right,
        step: String = "live-step",
        timestamp: TimeInterval
    ) -> NavigationInstruction {
        NavigationInstruction(
            maneuver: maneuver,
            roadName: maneuver == .destination ? "Đã đến nơi" : "Trần Phú",
            distanceToManeuverMeters: distance,
            remainingDistanceMeters: distance + 1_000,
            remainingTimeSeconds: 120,
            stepIdentifier: step,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )
    }

    private func waitUntil(
        timeoutIterations: Int = 100,
        condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<timeoutIterations {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition was not met before timeout")
    }
}

@MainActor
private final class ControllableNavigationProvider: NavigationProvider {
    let providerName = "Controllable Live Provider"
    private(set) var currentState: NavigationState = .idle
    private(set) var currentInstruction: NavigationInstruction?

    private let stateEvents = NavigationEventStream<NavigationState>()
    private let instructionEvents = NavigationEventStream<NavigationInstruction>()

    func initialize() async throws {
        transition(to: .idle)
    }

    func calculateRoute(to destination: Destination, travelMode: TravelMode) async throws {
        _ = destination
        _ = travelMode
        transition(to: .calculatingRoute)
        transition(to: .routePreview)
    }

    func startNavigation() async throws {
        transition(to: .navigating)
    }

    func stopNavigation() {
        transition(to: .stopped)
    }

    func stateStream() -> AsyncStream<NavigationState> {
        stateEvents.stream(initialValue: currentState)
    }

    func instructionStream() -> AsyncStream<NavigationInstruction> {
        instructionEvents.stream(initialValue: currentInstruction)
    }

    func emit(_ instruction: NavigationInstruction) {
        currentInstruction = instruction
        instructionEvents.yield(instruction)
    }

    private func transition(to state: NavigationState) {
        currentState = state
        stateEvents.yield(state)
    }
}

@MainActor
private final class LivePipelineSchedulerSpy: LocalNotificationScheduling {
    private(set) var contents: [NavigationNotificationContent] = []

    func schedule(_ content: NavigationNotificationContent) async throws {
        contents.append(content)
    }
}
