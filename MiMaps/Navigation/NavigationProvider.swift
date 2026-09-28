import Foundation

@MainActor
protocol NavigationProvider: AnyObject {
    var providerName: String { get }
    var currentState: NavigationState { get }
    var currentInstruction: NavigationInstruction? { get }

    func initialize() async throws
    func calculateRoute(to destination: Destination, travelMode: TravelMode) async throws
    func startNavigation() async throws
    func stopNavigation()
    func stateStream() -> AsyncStream<NavigationState>
    func instructionStream() -> AsyncStream<NavigationInstruction>
}

