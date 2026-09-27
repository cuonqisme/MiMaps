import Foundation
import UserNotifications

struct NavigationNotificationContent: Equatable, Sendable {
    let title: String
    let body: String
    let categoryIdentifier: String
    let soundEnabled: Bool
}

enum NotificationContentFactory {
    static func make(
        symbol: String,
        distanceText: String,
        roadName: String?,
        soundEnabled: Bool
    ) -> NavigationNotificationContent {
        NavigationNotificationContent(
            title: "\(symbol) \(distanceText)",
            body: roadName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? "Tiếp tục theo tuyến đường",
            categoryIdentifier: LocalNotificationService.navigationCategoryIdentifier,
            soundEnabled: soundEnabled
        )
    }
}

@MainActor
protocol LocalNotificationScheduling: AnyObject {
    func schedule(_ content: NavigationNotificationContent) async throws
}

@MainActor
final class LocalNotificationService: LocalNotificationScheduling {
    nonisolated static let navigationCategoryIdentifier = "NAVIGATION_MANEUVER"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func schedule(_ content: NavigationNotificationContent) async throws {
        let notification = UNMutableNotificationContent()
        notification.title = content.title
        notification.body = content.body
        notification.categoryIdentifier = content.categoryIdentifier
        notification.sound = content.soundEnabled ? .default : nil

        let request = UNNotificationRequest(
            identifier: "navigation-\(UUID().uuidString)",
            content: notification,
            trigger: nil
        )
        try await center.add(request)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
