import XCTest
@testable import MiBandNavigator

@MainActor
final class NavigationCoordinatorTests: XCTestCase {
    func testMockNavigationAutomaticallyDrivesBandTransport() async {
        let provider = MockNavigationProvider(automaticSimulationEnabled: false)
        let transport = BandTransportSpy()
        let coordinator = NavigationCoordinator(
            provider: provider,
            bandTransport: transport,
            notificationPolicy: BandNotificationPolicy(cooldownSeconds: 0)
        )

        await coordinator.startMockRoute()
        await waitUntil { transport.instructions.count == 1 }

        XCTAssertEqual(transport.instructions.first?.maneuver, .right)
        XCTAssertEqual(transport.instructions.first?.distanceToManeuverMeters, 500)

        provider.advance(by: 310)
        await waitUntil { transport.instructions.count == 2 }

        XCTAssertEqual(transport.instructions.last?.distanceToManeuverMeters, 200)
        XCTAssertEqual(coordinator.firedThresholds, [500, 200])
    }

    func testCoordinatorStopsProviderAndTransport() async {
        let provider = MockNavigationProvider(automaticSimulationEnabled: false)
        let transport = BandTransportSpy()
        let coordinator = NavigationCoordinator(provider: provider, bandTransport: transport)

        await coordinator.startMockRoute()
        coordinator.stopNavigation()

        XCTAssertEqual(provider.currentState, .stopped)
        XCTAssertEqual(transport.stopCount, 1)
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
private final class BandTransportSpy: BandTransport {
    private(set) var instructions: [NavigationInstruction] = []
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() async throws { startCount += 1 }
    func stop() { stopCount += 1 }
    func send(_ instruction: NavigationInstruction) async throws { instructions.append(instruction) }
}

