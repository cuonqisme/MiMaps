import XCTest
@testable import MiBandNavigator

@MainActor
final class MockNavigationProviderTests: XCTestCase {
    func testRouteStateTransitionsStartAndStop() async throws {
        let provider = MockNavigationProvider(automaticSimulationEnabled: false)

        try await provider.initialize()
        try await provider.calculateRoute(to: destination, travelMode: .motorcycle)
        XCTAssertEqual(provider.currentState, .routePreview)

        try await provider.startNavigation()
        XCTAssertEqual(provider.currentState, .navigating)
        XCTAssertEqual(provider.currentInstruction?.maneuver, .right)
        XCTAssertEqual(provider.currentInstruction?.distanceToManeuverMeters, 500)

        provider.stopNavigation()
        XCTAssertEqual(provider.currentState, .stopped)
    }

    func testPauseResumeAndSpeedControls() async throws {
        let provider = MockNavigationProvider(automaticSimulationEnabled: false)
        try await provider.calculateRoute(to: destination, travelMode: .car)
        try await provider.startNavigation()

        provider.pause()
        provider.advance(by: 100)
        XCTAssertEqual(provider.currentInstruction?.distanceToManeuverMeters, 500)

        provider.resume()
        provider.speedUp()
        provider.advance(by: 100)
        XCTAssertEqual(provider.speedMultiplier, 2)
        XCTAssertEqual(provider.currentInstruction?.distanceToManeuverMeters, 400)

        provider.slowDown()
        XCTAssertEqual(provider.speedMultiplier, 1)
    }

    func testNextManeuverAndArrival() async throws {
        let provider = MockNavigationProvider(automaticSimulationEnabled: false)
        try await provider.calculateRoute(to: destination, travelMode: .motorcycle)
        try await provider.startNavigation()

        provider.nextManeuver()
        XCTAssertEqual(provider.currentInstruction?.maneuver, .left)
        provider.nextManeuver()
        XCTAssertEqual(provider.currentInstruction?.maneuver, .roundaboutExit(2))
        provider.nextManeuver()
        XCTAssertEqual(provider.currentInstruction?.maneuver, .straight)
        provider.nextManeuver()

        XCTAssertEqual(provider.currentState, .arrived)
        XCTAssertEqual(provider.currentInstruction?.maneuver, .destination)
    }

    func testStartWithoutRouteFails() async {
        let provider = MockNavigationProvider(automaticSimulationEnabled: false)
        do {
            try await provider.startNavigation()
            XCTFail("Expected routeNotCalculated")
        } catch {
            XCTAssertEqual(error as? MockNavigationError, .routeNotCalculated)
        }
    }

    private var destination: Destination {
        Destination(displayName: "Test", latitude: 21, longitude: 105)
    }
}

