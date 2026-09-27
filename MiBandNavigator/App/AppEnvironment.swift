import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let settings: AppSettings
    let notificationPermissionManager: NotificationPermissionManager
    let localNotificationService: LocalNotificationService
    let mockNavigationProvider: MockNavigationProvider
    let navigationCoordinator: NavigationCoordinator
    let placesSearchService: GooglePlacesSearchService
    let locationPermissionManager: LocationPermissionManager
    let googleNavigationProvider: GoogleNavigationProvider
    let googleNavigationCoordinator: NavigationCoordinator

    init() {
        let settings = AppSettings()
        let notificationPermissionManager = NotificationPermissionManager()
        let localNotificationService = LocalNotificationService()
        let mockNavigationProvider = MockNavigationProvider()
        let placesSearchService = GooglePlacesSearchService()
        let locationPermissionManager = LocationPermissionManager()
        let googleNavigationProvider = GoogleNavigationProvider()
        let bandTransport = NotificationBandTransport(
            scheduler: localNotificationService,
            notificationsEnabled: { settings.bandNotificationsEnabled },
            soundEnabled: { settings.notificationSoundEnabled }
        )
        let googleBandTransport = NotificationBandTransport(
            scheduler: localNotificationService,
            notificationsEnabled: { settings.bandNotificationsEnabled },
            soundEnabled: { settings.notificationSoundEnabled }
        )

        self.settings = settings
        self.notificationPermissionManager = notificationPermissionManager
        self.localNotificationService = localNotificationService
        self.mockNavigationProvider = mockNavigationProvider
        self.placesSearchService = placesSearchService
        self.locationPermissionManager = locationPermissionManager
        self.googleNavigationProvider = googleNavigationProvider
        navigationCoordinator = NavigationCoordinator(
            provider: mockNavigationProvider,
            bandTransport: bandTransport
        )
        googleNavigationCoordinator = NavigationCoordinator(
            provider: googleNavigationProvider,
            bandTransport: googleBandTransport
        )
    }
}
