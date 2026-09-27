import Combine
import Foundation

enum MockNavigationError: LocalizedError, Equatable {
    case routeNotCalculated

    var errorDescription: String? {
        switch self {
        case .routeNotCalculated: "Hãy tạo tuyến mô phỏng trước khi bắt đầu."
        }
    }
}

@MainActor
final class MockNavigationProvider: ObservableObject, NavigationProvider {
    private struct Leg: Sendable {
        let identifier: String
        let maneuver: NavigationManeuver
        let roadName: String
        let distanceMeters: Double
    }

    let providerName = "Mock Navigation"
    let baseSpeedMetersPerSecond: Double
    let automaticSimulationEnabled: Bool

    @Published private(set) var currentState: NavigationState = .idle
    @Published private(set) var currentInstruction: NavigationInstruction?
    @Published private(set) var isPaused = false
    @Published private(set) var speedMultiplier = 1.0
    @Published private(set) var currentStepIndex = 0

    private let stateEvents = NavigationEventStream<NavigationState>()
    private let instructionEvents = NavigationEventStream<NavigationInstruction>()
    private var route: [Leg] = []
    private var distanceOnCurrentLeg = 0.0
    private var simulationTask: Task<Void, Never>?

    init(
        baseSpeedMetersPerSecond: Double = 12,
        automaticSimulationEnabled: Bool = true
    ) {
        self.baseSpeedMetersPerSecond = max(1, baseSpeedMetersPerSecond)
        self.automaticSimulationEnabled = automaticSimulationEnabled
    }

    func initialize() async throws {
        transition(to: .idle)
    }

    func calculateRoute(to destination: Destination, travelMode: TravelMode) async throws {
        _ = destination
        _ = travelMode
        transition(to: .calculatingRoute)
        route = Self.sampleRoute
        currentStepIndex = 0
        distanceOnCurrentLeg = route[0].distanceMeters
        currentInstruction = nil
        isPaused = false
        speedMultiplier = 1
        transition(to: .routePreview)
    }

    func startNavigation() async throws {
        guard !route.isEmpty else { throw MockNavigationError.routeNotCalculated }
        transition(to: .startingNavigation)
        transition(to: .navigating)
        emitCurrentInstruction()
        startAutomaticSimulationIfNeeded()
    }

    func stopNavigation() {
        simulationTask?.cancel()
        simulationTask = nil
        isPaused = false
        transition(to: .stopped)
    }

    func pause() {
        guard currentState == .navigating else { return }
        isPaused = true
    }

    func resume() {
        guard currentState == .navigating else { return }
        isPaused = false
    }

    func speedUp() {
        guard currentState == .navigating else { return }
        speedMultiplier = min(8, speedMultiplier * 2)
        emitCurrentInstruction()
    }

    func slowDown() {
        guard currentState == .navigating else { return }
        speedMultiplier = max(0.25, speedMultiplier / 2)
        emitCurrentInstruction()
    }

    func nextManeuver() {
        guard currentState == .navigating else { return }
        advanceToNextLeg()
    }

    func reset() {
        simulationTask?.cancel()
        simulationTask = nil
        route = []
        currentInstruction = nil
        currentStepIndex = 0
        distanceOnCurrentLeg = 0
        isPaused = false
        speedMultiplier = 1
        transition(to: .idle)
    }

    func advance(by distanceMeters: Double) {
        guard currentState == .navigating, !isPaused, !route.isEmpty else { return }
        var remainingAdvance = max(0, distanceMeters)

        while remainingAdvance >= distanceOnCurrentLeg, currentState == .navigating {
            remainingAdvance -= distanceOnCurrentLeg
            advanceToNextLeg()
        }

        guard currentState == .navigating else { return }
        distanceOnCurrentLeg = max(0, distanceOnCurrentLeg - remainingAdvance)
        emitCurrentInstruction()
    }

    func stateStream() -> AsyncStream<NavigationState> {
        stateEvents.stream(initialValue: currentState)
    }

    func instructionStream() -> AsyncStream<NavigationInstruction> {
        instructionEvents.stream(initialValue: currentInstruction)
    }

    private func startAutomaticSimulationIfNeeded() {
        guard automaticSimulationEnabled else { return }
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
                guard let self else { return }
                self.advance(by: self.baseSpeedMetersPerSecond * self.speedMultiplier * 0.25)
            }
        }
    }

    private func advanceToNextLeg() {
        guard currentStepIndex + 1 < route.count else {
            arrive()
            return
        }
        currentStepIndex += 1
        distanceOnCurrentLeg = route[currentStepIndex].distanceMeters
        emitCurrentInstruction()
    }

    private func arrive() {
        simulationTask?.cancel()
        simulationTask = nil
        let instruction = NavigationInstruction(
            maneuver: .destination,
            roadName: "Đã đến nơi",
            distanceToManeuverMeters: 0,
            remainingDistanceMeters: 0,
            remainingTimeSeconds: 0,
            stepIdentifier: "mock-arrival",
            timestamp: Date()
        )
        currentInstruction = instruction
        instructionEvents.yield(instruction)
        transition(to: .arrived)
    }

    private func emitCurrentInstruction() {
        guard route.indices.contains(currentStepIndex) else { return }
        let leg = route[currentStepIndex]
        let remainingDistance = distanceOnCurrentLeg
            + route.dropFirst(currentStepIndex + 1).reduce(0) { $0 + $1.distanceMeters }
        let speed = max(1, baseSpeedMetersPerSecond * speedMultiplier)
        let instruction = NavigationInstruction(
            maneuver: leg.maneuver,
            roadName: leg.roadName,
            distanceToManeuverMeters: distanceOnCurrentLeg,
            remainingDistanceMeters: remainingDistance,
            remainingTimeSeconds: remainingDistance / speed,
            stepIdentifier: leg.identifier,
            timestamp: Date()
        )
        currentInstruction = instruction
        instructionEvents.yield(instruction)
    }

    private func transition(to state: NavigationState) {
        currentState = state
        stateEvents.yield(state)
    }

    private static let sampleRoute: [Leg] = [
        Leg(identifier: "mock-right-tran-phu", maneuver: .right, roadName: "Trần Phú", distanceMeters: 500),
        Leg(identifier: "mock-left-le-thanh-tong", maneuver: .left, roadName: "Lê Thánh Tông", distanceMeters: 300),
        Leg(identifier: "mock-roundabout-exit-2", maneuver: .roundaboutExit(2), roadName: "Lối ra 2", distanceMeters: 1_000),
        Leg(identifier: "mock-final-leg", maneuver: .straight, roadName: "Điểm đến", distanceMeters: 700)
    ]
}
