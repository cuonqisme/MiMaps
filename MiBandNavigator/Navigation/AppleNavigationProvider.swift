@preconcurrency import CoreLocation
import Combine
import Foundation
import MapKit

enum AppleNavigationProviderError: LocalizedError {
    case locationUnavailable
    case invalidDestination
    case routeNotFound
    case routeNotCalculated

    var errorDescription: String? {
        switch self {
        case .locationUnavailable: "Không lấy được vị trí hiện tại."
        case .invalidDestination: "Điểm đến không hợp lệ."
        case .routeNotFound: "Apple Maps không tìm thấy tuyến phù hợp."
        case .routeNotCalculated: "Chưa có tuyến đường để bắt đầu điều hướng."
        }
    }
}

@MainActor
final class AppleNavigationProvider: NSObject, ObservableObject, NavigationProvider, @MainActor CLLocationManagerDelegate {
    let providerName = "Apple MapKit"

    @Published private(set) var currentState: NavigationState = .idle
    @Published private(set) var currentInstruction: NavigationInstruction?
    @Published private(set) var requestedTravelMode: TravelMode = .motorcycle
    @Published private(set) var activeTravelMode: TravelMode = .car
    @Published private(set) var fallbackUsed = false
    @Published private(set) var routePolyline: MKPolyline?
    @Published private(set) var routeRevision = 0
    @Published private(set) var backgroundUpdatesActive = false
    @Published private(set) var lastLocationUpdateAt: Date?
    @Published private(set) var lastLatitude: Double?
    @Published private(set) var lastLongitude: Double?
    @Published private(set) var lastSpeedMetersPerSecond: Double?
    @Published private(set) var lastCourseDegrees: Double?
    @Published private(set) var lastInstructionText: String?
    @Published private(set) var routeChangeCount = 0
    @Published private(set) var rerouteCount = 0

    private struct RouteStepSnapshot {
        let instructions: String
        let distance: CLLocationDistance
        let polyline: MKPolyline
    }

    private let stateEvents = NavigationEventStream<NavigationState>()
    private let instructionEvents = NavigationEventStream<NavigationInstruction>()
    private let classifier = AppleManeuverClassifier()
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var lastLocation: CLLocation?
    private var destination: Destination?
    private var routeSteps: [RouteStepSnapshot] = []
    private var routeDistance: CLLocationDistance = 0
    private var routeTravelTime: TimeInterval = 0
    private var currentStepIndex = 0
    private var offRouteUpdateCount = 0
    private var rerouteInProgress = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 3
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func initialize() async throws {
        guard CLLocationManager.locationServicesEnabled() else {
            throw AppleNavigationProviderError.locationUnavailable
        }
    }

    func calculateRoute(to destination: Destination, travelMode: TravelMode) async throws {
        guard CLLocationCoordinate2DIsValid(destination.coordinate) else {
            throw AppleNavigationProviderError.invalidDestination
        }
        transition(to: .calculatingRoute)
        requestedTravelMode = travelMode
        activeTravelMode = .car
        fallbackUsed = travelMode == .motorcycle
        self.destination = destination
        let source = try await currentLocation()
        try await rebuildRoute(from: source, isReroute: false)
        transition(to: .routePreview)
    }

    func startNavigation() async throws {
        guard routePolyline != nil else { throw AppleNavigationProviderError.routeNotCalculated }
        transition(to: .startingNavigation)
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.startUpdatingLocation()
        backgroundUpdatesActive = true
        transition(to: .navigating)
        if let lastLocation { updateGuidance(with: lastLocation) }
    }

    func stopNavigation() {
        stopLocationUpdates()
        destination = nil
        routeSteps = []
        routePolyline = nil
        routeDistance = 0
        routeTravelTime = 0
        currentInstruction = nil
        currentStepIndex = 0
        offRouteUpdateCount = 0
        transition(to: .stopped)
    }

    func stateStream() -> AsyncStream<NavigationState> {
        stateEvents.stream(initialValue: currentState)
    }

    func instructionStream() -> AsyncStream<NavigationInstruction> {
        instructionEvents.stream(initialValue: currentInstruction)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        _ = manager
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        lastLocation = location
        lastLocationUpdateAt = location.timestamp
        lastLatitude = location.coordinate.latitude
        lastLongitude = location.coordinate.longitude
        lastSpeedMetersPerSecond = location.speed >= 0 ? location.speed : nil
        lastCourseDegrees = location.course >= 0 ? location.course : nil

        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: location)
        }

        if currentState == .navigating || currentState == .rerouting {
            updateGuidance(with: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        _ = manager
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(throwing: error)
    }

    private func currentLocation() async throws -> CLLocation {
        if let lastLocation,
           lastLocation.horizontalAccuracy >= 0,
           abs(lastLocation.timestamp.timeIntervalSinceNow) < 30 {
            return lastLocation
        }

        return try await withCheckedThrowingContinuation { continuation in
            if let previous = locationContinuation {
                previous.resume(throwing: AppleNavigationProviderError.locationUnavailable)
            }
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func rebuildRoute(from sourceLocation: CLLocation, isReroute: Bool) async throws {
        guard let destination else { throw AppleNavigationProviderError.invalidDestination }
        let destinationLocation = CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        let request = MKDirections.Request()
        request.source = mapItem(for: sourceLocation, name: "Vị trí hiện tại")
        request.destination = mapItem(for: destinationLocation, name: destination.displayName)
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else { throw AppleNavigationProviderError.routeNotFound }

        routePolyline = route.polyline
        routeSteps = route.steps
            .filter { $0.polyline.pointCount > 0 && $0.distance > 0 }
            .map {
                RouteStepSnapshot(
                    instructions: $0.instructions.trimmingCharacters(in: .whitespacesAndNewlines),
                    distance: $0.distance,
                    polyline: $0.polyline
                )
            }
        guard !routeSteps.isEmpty else { throw AppleNavigationProviderError.routeNotFound }
        routeDistance = route.distance
        routeTravelTime = route.expectedTravelTime
        currentStepIndex = 0
        offRouteUpdateCount = 0
        routeRevision += 1
        if isReroute {
            routeChangeCount += 1
            rerouteCount += 1
        }
        updateGuidance(with: sourceLocation)
    }

    private func updateGuidance(with location: CLLocation) {
        guard let destination, !routeSteps.isEmpty else { return }
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        if location.distance(from: destinationLocation) <= 30 {
            arrive(at: destination)
            return
        }

        let searchEnd = min(routeSteps.count - 1, currentStepIndex + 5)
        if currentStepIndex <= searchEnd {
            let closest = (currentStepIndex...searchEnd).min { lhs, rhs in
                distance(from: location, to: routeSteps[lhs].polyline)
                    < distance(from: location, to: routeSteps[rhs].polyline)
            }
            if let closest { currentStepIndex = max(currentStepIndex, closest) }
        }

        let routeDistanceAway = routePolyline.map { distance(from: location, to: $0) } ?? 0
        if routeDistanceAway > 80, location.horizontalAccuracy <= 50 {
            offRouteUpdateCount += 1
        } else {
            offRouteUpdateCount = 0
        }
        if offRouteUpdateCount >= 3 { beginReroute(from: location) }

        let nextIndex = nextInstructionIndex(after: currentStepIndex)
        let nextStep = routeSteps[nextIndex]
        let maneuverDistance = distanceToStart(of: nextIndex, from: location)
        let remainingDistance = remainingRouteDistance(from: currentStepIndex, location: location)
        let remainingTime = routeDistance > 0
            ? routeTravelTime * min(1, remainingDistance / routeDistance)
            : 0
        let text = nextStep.instructions.isEmpty ? "Tiếp tục theo tuyến đường" : nextStep.instructions
        lastInstructionText = text
        emit(
            NavigationInstruction(
                maneuver: classifier.classify(text),
                roadName: text,
                distanceToManeuverMeters: maneuverDistance,
                remainingDistanceMeters: remainingDistance,
                remainingTimeSeconds: remainingTime,
                stepIdentifier: "apple-\(routeRevision)-\(nextIndex)",
                timestamp: location.timestamp,
                currentSpeedKPH: location.speed >= 0 ? location.speed * 3.6 : nil
            )
        )
    }

    private func beginReroute(from location: CLLocation) {
        guard !rerouteInProgress else { return }
        rerouteInProgress = true
        offRouteUpdateCount = 0
        transition(to: .rerouting)
        Task { [weak self] in
            guard let self else { return }
            defer { self.rerouteInProgress = false }
            do {
                try await self.rebuildRoute(from: location, isReroute: true)
                self.transition(to: .navigating)
            } catch {
                self.transition(to: .error(error.localizedDescription))
            }
        }
    }

    private func nextInstructionIndex(after index: Int) -> Int {
        guard index < routeSteps.count - 1 else { return index }
        return ((index + 1)..<routeSteps.count).first { !routeSteps[$0].instructions.isEmpty }
            ?? min(index + 1, routeSteps.count - 1)
    }

    private func distanceToStart(of stepIndex: Int, from location: CLLocation) -> CLLocationDistance {
        guard stepIndex > currentStepIndex else { return 0 }
        var result = remainingDistance(on: routeSteps[currentStepIndex], from: location)
        if stepIndex > currentStepIndex + 1 {
            for index in (currentStepIndex + 1)..<stepIndex {
                result += routeSteps[index].distance
            }
        }
        return max(0, result)
    }

    private func remainingRouteDistance(from stepIndex: Int, location: CLLocation) -> CLLocationDistance {
        var result = remainingDistance(on: routeSteps[stepIndex], from: location)
        if stepIndex < routeSteps.count - 1 {
            for index in (stepIndex + 1)..<routeSteps.count {
                result += routeSteps[index].distance
            }
        }
        return max(0, result)
    }

    private func remainingDistance(on step: RouteStepSnapshot, from location: CLLocation) -> CLLocationDistance {
        let coordinates = coordinates(in: step.polyline)
        guard !coordinates.isEmpty else { return step.distance }
        let nearestIndex = coordinates.indices.min { lhs, rhs in
            location.distance(from: self.location(for: coordinates[lhs]))
                < location.distance(from: self.location(for: coordinates[rhs]))
        } ?? 0
        var result = location.distance(from: self.location(for: coordinates[nearestIndex]))
        guard nearestIndex < coordinates.count - 1 else { return result }
        for index in nearestIndex..<(coordinates.count - 1) {
            result += self.location(for: coordinates[index]).distance(
                from: self.location(for: coordinates[index + 1])
            )
        }
        return result
    }

    private func distance(from location: CLLocation, to polyline: MKPolyline) -> CLLocationDistance {
        coordinates(in: polyline)
            .map { location.distance(from: self.location(for: $0)) }
            .min() ?? .greatestFiniteMagnitude
    }

    private func coordinates(in polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        guard polyline.pointCount > 0 else { return [] }
        var values = Array(
            repeating: kCLLocationCoordinate2DInvalid,
            count: polyline.pointCount
        )
        polyline.getCoordinates(&values, range: NSRange(location: 0, length: polyline.pointCount))
        return values
    }

    private func mapItem(for location: CLLocation, name: String) -> MKMapItem {
        let item: MKMapItem
        if #available(iOS 26.0, *) {
            item = MKMapItem(location: location, address: nil)
        } else {
            item = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        }
        item.name = name
        return item
    }

    private func location(for coordinate: CLLocationCoordinate2D) -> CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private func arrive(at destination: Destination) {
        stopLocationUpdates()
        emit(
            NavigationInstruction(
                maneuver: .destination,
                roadName: destination.displayName,
                distanceToManeuverMeters: 0,
                remainingDistanceMeters: 0,
                remainingTimeSeconds: 0,
                stepIdentifier: "apple-arrival-\(routeRevision)"
            )
        )
        transition(to: .arrived)
    }

    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = false
        backgroundUpdatesActive = false
    }

    private func transition(to state: NavigationState) {
        guard currentState != state else { return }
        currentState = state
        stateEvents.yield(state)
    }

    private func emit(_ instruction: NavigationInstruction) {
        currentInstruction = instruction
        instructionEvents.yield(instruction)
    }
}

private extension Destination {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
