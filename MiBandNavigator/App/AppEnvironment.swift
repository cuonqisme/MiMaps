import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let settings: AppSettings
    let notificationPermissionManager: NotificationPermissionManager
    let localNotificationService: LocalNotificationService
    let mockNavigationProvider: MockNavigationProvider
    let navigationCoordinator: NavigationCoordinator

    init() {
        let settings = AppSettings()
        let notificationPermissionManager = NotificationPermissionManager()
        let localNotificationService = LocalNotificationService()
        let mockNavigationProvider = MockNavigationProvider()
        let bandTransport = NotificationBandTransport(
            scheduler: localNotificationService,
            notificationsEnabled: { settings.bandNotificationsEnabled },
            soundEnabled: { settings.notificationSoundEnabled }
        )

        self.settings = settings
        self.notificationPermissionManager = notificationPermissionManager
        self.localNotificationService = localNotificationService
        self.mockNavigationProvider = mockNavigationProvider
        navigationCoordinator = NavigationCoordinator(
            provider: mockNavigationProvider,
            bandTransport: bandTransport
        )
    }
}
