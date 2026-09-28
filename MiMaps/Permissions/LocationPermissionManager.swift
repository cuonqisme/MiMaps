@preconcurrency import CoreLocation
import Combine
import Foundation

enum LocationPermissionStatus: String, Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case authorizedWhenInUse
    case authorizedAlways
    case servicesDisabled
    case unknown

    var isAuthorized: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }

    var localizedDescription: String {
        switch self {
        case .notDetermined: "Chưa yêu cầu"
        case .denied: "Đã từ chối"
        case .restricted: "Bị hạn chế"
        case .authorizedWhenInUse: "Cho phép khi dùng ứng dụng"
        case .authorizedAlways: "Luôn cho phép"
        case .servicesDisabled: "Dịch vụ vị trí đang tắt"
        case .unknown: "Không xác định"
        }
    }
}

@MainActor
protocol LocationPermissionManaging: AnyObject {
    func requestWhenInUse() async -> LocationPermissionStatus
    func requestBackgroundAuthorization() async -> LocationPermissionStatus
    func authorizationStatus() -> LocationPermissionStatus
}

@MainActor
final class LocationPermissionManager: NSObject, ObservableObject, LocationPermissionManaging, @MainActor CLLocationManagerDelegate {
    @Published private(set) var status: LocationPermissionStatus

    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<LocationPermissionStatus, Never>?

    override init() {
        manager = CLLocationManager()
        status = Self.currentStatus(for: manager)
        super.init()
        manager.delegate = self
    }

    func requestWhenInUse() async -> LocationPermissionStatus {
        status = Self.currentStatus(for: manager)
        guard status == .notDetermined else { return status }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestBackgroundAuthorization() async -> LocationPermissionStatus {
        let foregroundStatus = await requestWhenInUse()
        guard foregroundStatus == .authorizedWhenInUse else { return foregroundStatus }
        manager.requestAlwaysAuthorization()
        return status
    }

    func authorizationStatus() -> LocationPermissionStatus {
        status = Self.currentStatus(for: manager)
        return status
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = Self.currentStatus(for: manager)
        AppLogger.permission.info("Location permission changed: \(self.status.rawValue, privacy: .public)")
        guard status != .notDetermined, let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: status)
    }

    private static func currentStatus(for manager: CLLocationManager) -> LocationPermissionStatus {
        guard CLLocationManager.locationServicesEnabled() else { return .servicesDisabled }
        return switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorizedAlways: .authorizedAlways
        case .authorizedWhenInUse: .authorizedWhenInUse
        @unknown default: .unknown
        }
    }
}
