import Combine
import CoreLocation
import Foundation
import GoogleNavigation

enum GoogleNavigationProviderError: LocalizedError, Equatable {
    case apiKeyMissing
    case mapUnavailable
    case termsDeclined
    case navigatorUnavailable
    case invalidDestination
    case routeCalculationFailed(String)
    case routeNotCalculated

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing: "Chưa cấu hình GOOGLE_MAPS_API_KEY."
        case .mapUnavailable: "Bản đồ Google Navigation chưa sẵn sàng."
        case .termsDeclined: "Bạn phải chấp nhận điều khoản Google Navigation trước khi chỉ đường."
        case .navigatorUnavailable: "Google Navigator chưa sẵn sàng sau khi bật điều hướng."
        case .invalidDestination: "Điểm đến không hợp lệ."
        case let .routeCalculationFailed(message): "Không thể tính tuyến: \(message)"
        case .routeNotCalculated: "Chưa có tuyến đường để bắt đầu điều hướng."
        }
    }
}

enum GoogleRouteFailureReason: Sendable, Equatable {
    case travelModeUnsupported
    case other
}

enum TwoWheelerFallbackPolicy {
    static func shouldFallback(requestedMode: TravelMode, failure: GoogleRouteFailureReason) -> Bool {
        requestedMode == .motorcycle && failure == .travelModeUnsupported
    }
}

@MainActor
final class GoogleNavigationProvider: NSObject, ObservableObject, NavigationProvider, @MainActor GMSNavigatorListener, @MainActor GMSRoadSnappedLocationProviderListener {
    let providerName = "Google Navigation SDK"

    @Published private(set) var currentState: NavigationState = .idle
    @Published private(set) var currentInstruction: NavigationInstruction?
    @Published private(set) var requestedTravelMode: TravelMode = .motorcycle
    @Published private(set) var activeTravelMode: TravelMode = .motorcycle
    @Published private(set) var fallbackUsed = false
    @Published private(set) var routeRevision = 0
    @Published private(set) var backgroundUpdatesActive = false
    @Published private(set) var lastLocationUpdateAt: Date?

    private let stateEvents = NavigationEventStream<NavigationState>()
    private let instructionEvents = NavigationEventStream<NavigationInstruction>()
    private let instructionFactory = GoogleNavigationInstructionFactory()
    private weak var mapView: GMSMapView?
    private var navigator: GMSNavigator?
    private var roadSnappedLocationProvider: GMSRoadSnappedLocationProvider?
    private var routeIsCalculated = false
    private var isInitialized = false

    func attach(mapView: GMSMapView) {
        self.mapView = mapView
        if GMSNavigationServices.areTermsAndConditionsAccepted() {
            configureNavigation(on: mapView)
        }
    }

    func initialize() async throws {
        guard AppConfig.googleMapsAPIKey != nil else { throw GoogleNavigationProviderError.apiKeyMissing }
        guard let mapView else { throw GoogleNavigationProviderError.mapUnavailable }
        guard !isInitialized else { return }

        if !GMSNavigationServices.areTermsAndConditionsAccepted() {
            let options = GMSNavigationTermsAndConditionsOptions(companyName: "MiBand Navigator")
            let accepted = await withCheckedContinuation { continuation in
                GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(with: options) { accepted in
                    continuation.resume(returning: accepted)
                }
            }
            guard accepted else { throw GoogleNavigationProviderError.termsDeclined }
        }

        configureNavigation(on: mapView)
        guard navigator != nil else { throw GoogleNavigationProviderError.navigatorUnavailable }
        isInitialized = true
        transition(to: .idle)
    }

    func calculateRoute(to destination: Destination, travelMode: TravelMode) async throws {
        try await initialize()
        guard let mapView, let navigator else { throw GoogleNavigationProviderError.navigatorUnavailable }
        guard let waypoint = makeWaypoint(from: destination) else {
            throw GoogleNavigationProviderError.invalidDestination
        }

        transition(to: .calculatingRoute)
        requestedTravelMode = travelMode
        activeTravelMode = travelMode
        fallbackUsed = false
        mapView.travelMode = googleTravelMode(for: travelMode)

        var status = await requestRoute(navigator: navigator, waypoint: waypoint)
        if TwoWheelerFallbackPolicy.shouldFallback(
            requestedMode: travelMode,
            failure: failureReason(for: status)
        ) {
            fallbackUsed = true
            activeTravelMode = .car
            mapView.travelMode = .driving
            status = await requestRoute(navigator: navigator, waypoint: waypoint)
        }

        guard status == .OK else {
            routeIsCalculated = false
            throw GoogleNavigationProviderError.routeCalculationFailed(description(for: status))
        }

        routeIsCalculated = true
        transition(to: .routePreview)
    }

    func startNavigation() async throws {
        guard routeIsCalculated, let navigator, let mapView else {
            throw GoogleNavigationProviderError.routeNotCalculated
        }
        transition(to: .startingNavigation)
        navigator.isGuidanceActive = true
        navigator.sendsBackgroundNotifications = false
        startBackgroundLocationUpdates()
        mapView.cameraMode = .following
        transition(to: .navigating)
    }

    func stopNavigation() {
        navigator?.isGuidanceActive = false
        stopBackgroundLocationUpdates()
        navigator?.clearDestinations()
        routeIsCalculated = false
        transition(to: .stopped)
    }

    func stateStream() -> AsyncStream<NavigationState> {
        stateEvents.stream(initialValue: currentState)
    }

    func instructionStream() -> AsyncStream<NavigationInstruction> {
        instructionEvents.stream(initialValue: currentInstruction)
    }

    func navigator(_ navigator: GMSNavigator, didUpdate navInfo: GMSNavigationNavInfo) {
        switch navInfo.navState {
        case .enroute:
            if currentState != .arrived {
                transition(to: .navigating)
            }
        case .rerouting:
            transition(to: .rerouting)
        case .stopped:
            if currentState != .arrived && currentState != .stopped {
                transition(to: .stopped)
            }
        case .unknown:
            break
        @unknown default:
            break
        }

        guard navInfo.navState == .enroute, let step = navInfo.currentStep else { return }
        let snapshot = GoogleNavigationFeedSnapshot(
            maneuverRawValue: step.maneuver.rawValue,
            roundaboutTurnNumber: step.roundaboutTurnNumber,
            routeRevision: routeRevision,
            stepNumber: step.stepNumber,
            roadName: step.fullRoadName,
            distanceToManeuverMeters: navInfo.distanceToCurrentStepMeters,
            remainingDistanceMeters: navInfo.distanceToFinalDestinationMeters,
            remainingTimeSeconds: navInfo.timeToFinalDestinationSeconds
        )
        emit(instructionFactory.makeInstruction(from: snapshot))
    }

    func navigatorDidChangeRoute(_ navigator: GMSNavigator) {
        routeRevision += 1
        if currentState == .navigating || currentState == .rerouting {
            transition(to: .rerouting)
        }
    }

    func navigator(_ navigator: GMSNavigator, didArriveAt waypoint: GMSNavigationWaypoint) {
        navigator.isGuidanceActive = false
        stopBackgroundLocationUpdates()
        routeIsCalculated = false
        emit(
            NavigationInstruction(
                maneuver: .destination,
                roadName: waypoint.title,
                distanceToManeuverMeters: 0,
                remainingDistanceMeters: 0,
                remainingTimeSeconds: 0,
                stepIdentifier: "google-arrival-\(routeRevision)",
                timestamp: Date()
            )
        )
        transition(to: .arrived)
    }

    func locationProvider(
        _ locationProvider: GMSRoadSnappedLocationProvider,
        didUpdate location: CLLocation
    ) {
        _ = locationProvider
        lastLocationUpdateAt = location.timestamp
    }

    private func configureNavigation(on mapView: GMSMapView) {
        mapView.isNavigationEnabled = true
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        let newNavigator = mapView.navigator
        if navigator !== newNavigator {
            if let navigator {
                _ = navigator.remove(self)
            }
            navigator = newNavigator
            navigator?.add(self)
            navigator?.distanceUpdateThreshold = 1
            navigator?.timeUpdateThreshold = 1
        }
        let newLocationProvider = mapView.roadSnappedLocationProvider
        if roadSnappedLocationProvider !== newLocationProvider {
            if let roadSnappedLocationProvider {
                roadSnappedLocationProvider.stopUpdatingLocation()
                _ = roadSnappedLocationProvider.remove(self)
            }
            roadSnappedLocationProvider = newLocationProvider
        }
    }

    private func makeWaypoint(from destination: Destination) -> GMSNavigationWaypoint? {
        if let placeID = destination.placeID, !placeID.isEmpty {
            return GMSNavigationWaypoint(placeID: placeID, title: destination.displayName)
        }
        return GMSNavigationWaypoint(
            location: CLLocationCoordinate2D(
                latitude: destination.latitude,
                longitude: destination.longitude
            ),
            title: destination.displayName
        )
    }

    private func requestRoute(
        navigator: GMSNavigator,
        waypoint: GMSNavigationWaypoint
    ) async -> GMSRouteStatus {
        await withCheckedContinuation { continuation in
            navigator.setDestinations([waypoint]) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func googleTravelMode(for mode: TravelMode) -> GMSNavigationTravelMode {
        switch mode {
        case .motorcycle: .twoWheeler
        case .car: .driving
        }
    }

    private func failureReason(for status: GMSRouteStatus) -> GoogleRouteFailureReason {
        status == .travelModeUnsupported ? .travelModeUnsupported : .other
    }

    private func description(for status: GMSRouteStatus) -> String {
        switch status {
        case .internalError: "Lỗi nội bộ Google Navigation"
        case .OK: "Thành công"
        case .noRouteFound: "Không tìm thấy tuyến"
        case .networkError: "Lỗi mạng"
        case .quotaExceeded: "Đã vượt hạn mức Google Maps Platform"
        case .apiKeyNotAuthorized: "API key chưa được cấp quyền Navigation SDK"
        case .canceled: "Yêu cầu bị hủy"
        case .duplicateWaypointsError: "Điểm dừng bị trùng"
        case .noWaypointsError: "Thiếu điểm đến"
        case .locationUnavailable: "Vị trí hiện tại chưa khả dụng"
        case .waypointError: "Điểm đến không hợp lệ hoặc đã cũ"
        case .travelModeUnsupported: "Chế độ di chuyển không được hỗ trợ"
        @unknown default: "Lỗi không xác định (\(status.rawValue))"
        }
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

    private func startBackgroundLocationUpdates() {
        guard !backgroundUpdatesActive, let roadSnappedLocationProvider else { return }
        roadSnappedLocationProvider.add(self)
        roadSnappedLocationProvider.allowsBackgroundLocationUpdates = true
        roadSnappedLocationProvider.startUpdatingLocation()
        backgroundUpdatesActive = true
    }

    private func stopBackgroundLocationUpdates() {
        guard let roadSnappedLocationProvider else {
            backgroundUpdatesActive = false
            return
        }
        roadSnappedLocationProvider.stopUpdatingLocation()
        roadSnappedLocationProvider.allowsBackgroundLocationUpdates = false
        _ = roadSnappedLocationProvider.remove(self)
        backgroundUpdatesActive = false
    }
}
