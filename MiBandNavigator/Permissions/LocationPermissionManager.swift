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
final class LocationPermissionManager: NSObject, ObservableObject, @MainActor CLLocationManagerDelegate {
    @Published private(set) var status: LocationPermissionStatus

    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<LocationPermissionStatus, Never>?

    override init() {
        manager = CLLocationManager()
        status = Self.currentStatus
        super.init()
        manager.delegate = self
    }

    func requestWhenInUse() async -> LocationPermissionStatus {
        status = Self.currentStatus
        guard status == .notDetermined else { return status }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = Self.currentStatus
        guard status != .notDetermined, let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: status)
    }

    private static var currentStatus: LocationPermissionStatus {
        guard CLLocationManager.locationServicesEnabled() else { return .servicesDisabled }
        return switch CLLocationManager.authorizationStatus() {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorizedAlways: .authorizedAlways
        case .authorizedWhenInUse: .authorizedWhenInUse
        @unknown default: .unknown
        }
    }
}
