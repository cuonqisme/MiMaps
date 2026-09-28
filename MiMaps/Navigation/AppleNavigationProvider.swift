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
    @Published private(set) var routePolylines: [MKPolyline] = []
    @Published private(set) var routeOptions: [RouteOptionSummary] = []
    @Published private(set) var selectedRouteIndex = 0
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
        let coordinates: [CLLocationCoordinate2D]
        let startProgressMeters: CLLocationDistance
        let endProgressMeters: CLLocationDistance
        let stableIdentifier: String
    }

    private let stateEvents = NavigationEventStream<NavigationState>()
    private let instructionEvents = NavigationEventStream<NavigationInstruction>()
    private let classifier = AppleManeuverClassifier()
    private let instructionParser = AppleInstructionParser()
    private let locationManager = CLLocationManager()
    private let preferencesProvider: @MainActor () -> RoutePreferences
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var lastLocation: CLLocation?
    private var destination: Destination?
    private var routeSteps: [RouteStepSnapshot] = []
    private var routeGeometry: RouteGeometry?
    private var routeDistance: CLLocationDistance = 0
    private var routeTravelTime: TimeInterval = 0
    private var routeProgressMeters: CLLocationDistance?
    private var lastProgressTimestamp: Date?
    private var activeInstructionIndex: Int?
    private var offRouteUpdateCount = 0
    private var rerouteInProgress = false
    private var lastRerouteAt: Date?
    private var routeCandidates: [MKRoute] = []

    init(
        preferencesProvider: @escaping @MainActor () -> RoutePreferences = { .standard }
    ) {
        self.preferencesProvider = preferencesProvider
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
        activeTravelMode = travelMode == .motorcycle ? .car : travelMode
        fallbackUsed = travelMode == .motorcycle
        locationManager.activityType = travelMode == .walking ? .fitness : .automotiveNavigation
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
        routeCandidates = []
        routePolyline = nil
        routePolylines = []
        routeOptions = []
        selectedRouteIndex = 0
        routeDistance = 0
        routeTravelTime = 0
        routeGeometry = nil
        routeProgressMeters = nil
        lastProgressTimestamp = nil
        activeInstructionIndex = nil
        currentInstruction = nil
        lastInstructionText = nil
        offRouteUpdateCount = 0
        lastRerouteAt = nil
        routeRevision += 1
        transition(to: .stopped)
    }

    func stateStream() -> AsyncStream<NavigationState> {
        stateEvents.stream(initialValue: currentState)
    }

    func instructionStream() -> AsyncStream<NavigationInstruction> {
        instructionEvents.stream(initialValue: currentInstruction)
    }

    func selectRoute(at index: Int) {
        guard routeCandidates.indices.contains(index),
              let location = lastLocation else { return }
        do {
            try applyRoute(routeCandidates[index], index: index, from: location, isReroute: false)
        } catch {
            transition(to: .error(error.localizedDescription))
        }
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
        request.transportType = transportType(for: activeTravelMode)
        request.requestsAlternateRoutes = true
        let preferences = preferencesProvider()
        request.tollPreference = preferences.avoidTolls ? .avoid : .any
        request.highwayPreference = preferences.avoidHighways ? .avoid : .any

        let response = try await MKDirections(request: request).calculate()
        guard !response.routes.isEmpty else { throw AppleNavigationProviderError.routeNotFound }
        routeCandidates = response.routes
        routePolylines = response.routes.map(\.polyline)
        routeOptions = makeRouteSummaries(response.routes)
        try applyRoute(response.routes[0], index: 0, from: sourceLocation, isReroute: isReroute)
    }

    private func applyRoute(
        _ route: MKRoute,
        index: Int,
        from sourceLocation: CLLocation,
        isReroute: Bool
    ) throws {
        let candidateSteps = route.steps.filter { $0.polyline.pointCount > 0 && $0.distance > 0 }
        guard let geometry = RouteGeometry(coordinates: coordinates(in: route.polyline)),
              !candidateSteps.isEmpty else {
            throw AppleNavigationProviderError.routeNotFound
        }
        let totalStepDistance = candidateSteps.reduce(0) { $0 + $1.distance }
        guard totalStepDistance > 0 else { throw AppleNavigationProviderError.routeNotFound }

        selectedRouteIndex = index
        routePolyline = route.polyline
        routeGeometry = geometry
        var cumulativeStepDistance = 0.0
        routeSteps = candidateSteps.map { step in
            let instructions = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            let stepCoordinates = coordinates(in: step.polyline)
            let startProgress = geometry.totalDistanceMeters
                * cumulativeStepDistance / totalStepDistance
            cumulativeStepDistance += step.distance
            let endProgress = geometry.totalDistanceMeters
                * cumulativeStepDistance / totalStepDistance
            return RouteStepSnapshot(
                instructions: instructions,
                distance: step.distance,
                coordinates: stepCoordinates,
                startProgressMeters: startProgress,
                endProgressMeters: endProgress,
                stableIdentifier: stableStepIdentifier(
                    instructions: instructions,
                    coordinate: stepCoordinates.first
                )
            )
        }
        routeDistance = route.distance
        routeTravelTime = route.expectedTravelTime
        routeProgressMeters = nil
        lastProgressTimestamp = nil
        activeInstructionIndex = routeSteps.indices.first { !routeSteps[$0].instructions.isEmpty }
        offRouteUpdateCount = 0
        if !isReroute { lastRerouteAt = nil }
        routeRevision += 1
        if isReroute {
            routeChangeCount += 1
            rerouteCount += 1
        }
        updateGuidance(with: sourceLocation)
    }

    private func makeRouteSummaries(_ routes: [MKRoute]) -> [RouteOptionSummary] {
        let fastestTime = routes.map(\.expectedTravelTime).min() ?? 0
        let shortestDistance = routes.map(\.distance).min() ?? 0
        return routes.enumerated().map { index, route in
            var advantages: [String] = []
            var disadvantages: [String] = []
            if route.expectedTravelTime <= fastestTime + 1 { advantages.append("Nhanh nhất") }
            if route.distance <= shortestDistance + 1 { advantages.append("Ngắn nhất") }
            if !route.hasTolls { advantages.append("Không trạm thu phí") }
            if !route.hasHighways { advantages.append("Không đường cao tốc") }
            if route.hasTolls { disadvantages.append("Có trạm thu phí") }
            if route.hasHighways { disadvantages.append("Có đường cao tốc") }
            let extraTime = route.expectedTravelTime - fastestTime
            if extraTime >= 60 {
                disadvantages.append("Chậm hơn \(Int((extraTime / 60).rounded())) phút")
            }
            let extraDistance = route.distance - shortestDistance
            if extraDistance >= 500 {
                disadvantages.append("Dài hơn \(DistanceFormatter.string(fromMeters: extraDistance))")
            }
            disadvantages.append(contentsOf: route.advisoryNotices.prefix(2))
            return RouteOptionSummary(
                id: index,
                name: route.name.isEmpty ? "Tuyến \(index + 1)" : route.name,
                distanceMeters: route.distance,
                expectedTravelTimeSeconds: route.expectedTravelTime,
                advantages: advantages,
                disadvantages: disadvantages,
                hasTolls: route.hasTolls,
                hasHighways: route.hasHighways
            )
        }
    }

    private func transportType(for travelMode: TravelMode) -> MKDirectionsTransportType {
        switch travelMode {
        case .motorcycle, .car: .automobile
        case .walking: .walking
        case .transit: .transit
        }
    }

    private func updateGuidance(with location: CLLocation) {
        guard let destination,
              let routeGeometry,
              !routeSteps.isEmpty else { return }
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        if location.distance(from: destinationLocation) <= 30 {
            arrive(at: destination)
            return
        }

        let elapsed = lastProgressTimestamp.map {
            max(1, location.timestamp.timeIntervalSince($0))
        } ?? 1
        let course = location.course >= 0 && location.speed >= 2 ? location.course : nil
        guard let projection = routeGeometry.project(
            coordinate: location.coordinate,
            previousProgressMeters: routeProgressMeters,
            elapsedTime: elapsed,
            speedMetersPerSecond: location.speed >= 0 ? location.speed : nil,
            horizontalAccuracy: location.horizontalAccuracy,
            courseDegrees: course
        ) else { return }
        routeProgressMeters = projection.progressMeters
        lastProgressTimestamp = location.timestamp

        let offRouteDistance = max(65, location.horizontalAccuracy * 2)
        let movingWrongWay = location.speed >= 4
            && (projection.headingDifferenceDegrees ?? 0) >= 110
        if (projection.distanceFromRouteMeters > offRouteDistance || movingWrongWay),
           location.horizontalAccuracy <= 50 {
            offRouteUpdateCount += 1
        } else {
            offRouteUpdateCount = 0
        }
        if offRouteUpdateCount >= 3, canReroute(at: location.timestamp) {
            lastRerouteAt = location.timestamp
            beginReroute(from: location)
            return
        }

        guard let nextIndex = instructionIndex(
            at: projection.progressMeters,
            horizontalAccuracy: location.horizontalAccuracy
        ) else { return }
        activeInstructionIndex = nextIndex
        let nextStep = routeSteps[nextIndex]
        let maneuverDistance = max(0, nextStep.startProgressMeters - projection.progressMeters)
        let remainingGeometryDistance = max(
            0,
            routeGeometry.totalDistanceMeters - projection.progressMeters
        )
        let remainingDistance = routeGeometry.totalDistanceMeters > 0
            ? routeDistance * remainingGeometryDistance / routeGeometry.totalDistanceMeters
            : 0
        let remainingTime = routeDistance > 0
            ? routeTravelTime * min(1, remainingDistance / routeDistance)
            : 0
        let text = nextStep.instructions.isEmpty ? "Tiếp tục theo tuyến đường" : nextStep.instructions
        lastInstructionText = text
        let maneuver = classifier.classify(
            text,
            turnAngleDegrees: turnAngleDegrees(at: nextIndex)
        )
        emit(
            NavigationInstruction(
                maneuver: maneuver,
                roadName: instructionParser.conciseRoadName(from: text),
                distanceToManeuverMeters: maneuverDistance,
                remainingDistanceMeters: remainingDistance,
                remainingTimeSeconds: remainingTime,
                stepIdentifier: nextStep.stableIdentifier,
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

    private func instructionIndex(
        at progress: CLLocationDistance,
        horizontalAccuracy: CLLocationAccuracy
    ) -> Int? {
        let passAllowance = min(45, max(20, horizontalAccuracy))
        if let activeInstructionIndex,
           routeSteps.indices.contains(activeInstructionIndex),
           !routeSteps[activeInstructionIndex].instructions.isEmpty,
           progress <= routeSteps[activeInstructionIndex].startProgressMeters + passAllowance {
            return activeInstructionIndex
        }

        let searchStart = min((activeInstructionIndex ?? -1) + 1, routeSteps.count)
        if searchStart < routeSteps.count,
           let next = (searchStart..<routeSteps.count).first(where: {
               !routeSteps[$0].instructions.isEmpty
                   && routeSteps[$0].startProgressMeters >= progress - passAllowance
           }) {
            return next
        }
        return routeSteps.indices.reversed().first { !routeSteps[$0].instructions.isEmpty }
    }

    private func canReroute(at timestamp: Date) -> Bool {
        guard !rerouteInProgress else { return false }
        return lastRerouteAt.map { timestamp.timeIntervalSince($0) >= 25 } ?? true
    }

    private func turnAngleDegrees(at stepIndex: Int) -> Double? {
        guard routeSteps.indices.contains(stepIndex),
              let outgoing = firstDistinctSegment(in: routeSteps[stepIndex].coordinates) else {
            return nil
        }
        guard let previousIndex = routeSteps.indices[..<stepIndex].reversed().first(where: {
            lastDistinctSegment(in: routeSteps[$0].coordinates) != nil
        }),
              let incoming = lastDistinctSegment(in: routeSteps[previousIndex].coordinates) else {
            return nil
        }
        return RouteGeometry.signedTurnAngleDegrees(
            incomingStart: incoming.0,
            incomingEnd: incoming.1,
            outgoingStart: outgoing.0,
            outgoingEnd: outgoing.1
        )
    }

    private func firstDistinctSegment(
        in coordinates: [CLLocationCoordinate2D]
    ) -> (CLLocationCoordinate2D, CLLocationCoordinate2D)? {
        guard coordinates.count >= 2 else { return nil }
        for index in 0..<(coordinates.count - 1)
        where location(for: coordinates[index]).distance(from: location(for: coordinates[index + 1])) >= 2 {
            return (coordinates[index], coordinates[index + 1])
        }
        return nil
    }

    private func lastDistinctSegment(
        in coordinates: [CLLocationCoordinate2D]
    ) -> (CLLocationCoordinate2D, CLLocationCoordinate2D)? {
        guard coordinates.count >= 2 else { return nil }
        for index in stride(from: coordinates.count - 1, through: 1, by: -1)
        where location(for: coordinates[index - 1]).distance(from: location(for: coordinates[index])) >= 2 {
            return (coordinates[index - 1], coordinates[index])
        }
        return nil
    }

    private func stableStepIdentifier(
        instructions: String,
        coordinate: CLLocationCoordinate2D?
    ) -> String {
        let normalized = instructions
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased()
            .replacingOccurrences(of: "đ", with: "d")
        let coordinate = coordinate ?? kCLLocationCoordinate2DInvalid
        return String(
            format: "apple:%.4f:%.4f:%@",
            locale: Locale(identifier: "en_US_POSIX"),
            coordinate.latitude,
            coordinate.longitude,
            String(normalized.prefix(80))
        )
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
