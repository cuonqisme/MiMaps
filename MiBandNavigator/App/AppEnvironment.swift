import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let settings: AppSettings
    let notificationPermissionManager: NotificationPermissionManager
    let localNotificationService: LocalNotificationService
    let mockNavigationProvider: MockNavigationProvider
    let navigationCoordinator: NavigationCoordinator
    let placesSearchService: ApplePlacesSearchService
    let locationPermissionManager: LocationPermissionManager
    let liveNavigationProvider: AppleNavigationProvider
    let liveNavigationCoordinator: NavigationCoordinator
    let navigationPermissionPreflight: NavigationPermissionPreflight

    init() {
        let settings = AppSettings()
        let notificationPermissionManager = NotificationPermissionManager()
        let localNotificationService = LocalNotificationService()
        let mockNavigationProvider = MockNavigationProvider()
        let placesSearchService = ApplePlacesSearchService()
        let locationPermissionManager = LocationPermissionManager()
        let liveNavigationProvider = AppleNavigationProvider()
        let bandTransport = NotificationBandTransport(
            scheduler: localNotificationService,
            notificationsEnabled: { settings.bandNotificationsEnabled },
            soundEnabled: { settings.notificationSoundEnabled }
        )
        let liveBandTransport = NotificationBandTransport(
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
        self.liveNavigationProvider = liveNavigationProvider
        navigationPermissionPreflight = NavigationPermissionPreflight(
            locationManager: locationPermissionManager,
            notificationManager: notificationPermissionManager
        )
        navigationCoordinator = NavigationCoordinator(
            provider: mockNavigationProvider,
            bandTransport: bandTransport,
            notificationThresholdProvider: { settings.notificationThresholds }
        )
        liveNavigationCoordinator = NavigationCoordinator(
            provider: liveNavigationProvider,
            bandTransport: liveBandTransport,
            notificationThresholdProvider: { settings.notificationThresholds }
        )
    }
}
