import Foundation

struct NavigationPermissionPreflightResult: Sendable, Equatable {
    let locationStatus: LocationPermissionStatus
    let notificationStatus: NotificationPermissionStatus
    let notificationRequestError: String?
    let notificationsRequired: Bool

    var canStartNavigation: Bool { locationStatus.isAuthorized }

    var warning: String? {
        if !locationStatus.isAuthorized {
            return "Cần cho phép vị trí để bắt đầu chỉ đường."
        }
        if locationStatus == .authorizedWhenInUse {
            return "Để chỉ đường ổn định khi khóa màn hình, hãy chọn Luôn cho phép vị trí."
        }
        guard notificationsRequired else { return nil }
        if let notificationRequestError {
            return "Không thể yêu cầu quyền thông báo: \(notificationRequestError)"
        }
        if notificationStatus == .denied {
            return "Thông báo đang bị tắt; Mi Band sẽ không nhận chỉ dẫn. Hãy bật trong Cài đặt iOS."
        }
        if notificationStatus == .unknown {
            return "Không xác định được quyền thông báo; hãy kiểm tra Cài đặt iOS."
        }
        return nil
    }

    var shouldOfferSettings: Bool {
        !locationStatus.isAuthorized || (notificationsRequired && notificationStatus == .denied)
    }
}

@MainActor
final class NavigationPermissionPreflight {
    private let locationManager: LocationPermissionManaging
    private let notificationManager: NotificationPermissionManaging

    init(
        locationManager: LocationPermissionManaging,
        notificationManager: NotificationPermissionManaging
    ) {
        self.locationManager = locationManager
        self.notificationManager = notificationManager
    }

    func prepare(notificationsRequired: Bool) async -> NavigationPermissionPreflightResult {
        let locationStatus = await locationManager.requestBackgroundAuthorization()
        guard locationStatus.isAuthorized else {
            return NavigationPermissionPreflightResult(
                locationStatus: locationStatus,
                notificationStatus: await notificationManager.authorizationStatus(),
                notificationRequestError: nil,
                notificationsRequired: notificationsRequired
            )
        }

        var notificationStatus = await notificationManager.authorizationStatus()
        var requestError: String?
        if notificationsRequired, notificationStatus == .notDetermined {
            do {
                _ = try await notificationManager.requestAuthorization()
                notificationStatus = await notificationManager.authorizationStatus()
            } catch {
                requestError = error.localizedDescription
            }
        }

        return NavigationPermissionPreflightResult(
            locationStatus: locationStatus,
            notificationStatus: notificationStatus,
            notificationRequestError: requestError,
            notificationsRequired: notificationsRequired
        )
    }
}
