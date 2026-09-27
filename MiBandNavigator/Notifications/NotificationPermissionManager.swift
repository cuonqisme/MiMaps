import Foundation
import UserNotifications

enum NotificationPermissionStatus: String, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    var localizedDescription: String {
        switch self {
        case .notDetermined: "Chưa yêu cầu"
        case .denied: "Đã từ chối"
        case .authorized: "Đã cho phép"
        case .provisional: "Cho phép tạm thời"
        case .ephemeral: "Cho phép trong phiên"
        case .unknown: "Không xác định"
        }
    }
}

@MainActor
protocol NotificationPermissionManaging: AnyObject {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> NotificationPermissionStatus
}

@MainActor
final class NotificationPermissionManager: NotificationPermissionManaging {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func authorizationStatus() async -> NotificationPermissionStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        @unknown default: .unknown
        }
    }
}

