import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let settings: AppSettings
    let notificationPermissionManager: NotificationPermissionManager
    let localNotificationService: LocalNotificationService

    init(
        settings: AppSettings = AppSettings(),
        notificationPermissionManager: NotificationPermissionManager = NotificationPermissionManager(),
        localNotificationService: LocalNotificationService = LocalNotificationService()
    ) {
        self.settings = settings
        self.notificationPermissionManager = notificationPermissionManager
        self.localNotificationService = localNotificationService
    }
}

