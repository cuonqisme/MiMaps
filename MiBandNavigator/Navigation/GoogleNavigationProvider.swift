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
final class GoogleNavigationProvider: ObservableObject, NavigationProvider {
    let providerName = "Google Navigation SDK"

    @Published private(set) var currentState: NavigationState = .idle
    @Published private(set) var currentInstruction: NavigationInstruction?
    @Published private(set) var requestedTravelMode: TravelMode = .motorcycle
    @Published private(set) var activeTravelMode: TravelMode = .motorcycle
    @Published private(set) var fallbackUsed = false

    private let stateEvents = NavigationEventStream<NavigationState>()
    private let instructionEvents = NavigationEventStream<NavigationInstruction>()
    private weak var mapView: GMSMapView?
    private var navigator: GMSNavigator?
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
        mapView.cameraMode = .following
        transition(to: .navigating)
    }

    func stopNavigation() {
        navigator?.isGuidanceActive = false
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

    private func configureNavigation(on mapView: GMSMapView) {
        mapView.isNavigationEnabled = true
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        navigator = mapView.navigator
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
        currentState = state
        stateEvents.yield(state)
    }
}

