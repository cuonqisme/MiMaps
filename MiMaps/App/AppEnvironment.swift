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
    let sharedLocationImporter: GoogleMapsLocationImporter
    let locationPermissionManager: LocationPermissionManager
    let liveNavigationProvider: AppleNavigationProvider
    let liveNavigationCoordinator: NavigationCoordinator
    let navigationPermissionPreflight: NavigationPermissionPreflight
    let miBandConnection: MiBandDirectConnection

    init() {
        let settings = AppSettings()
        let notificationPermissionManager = NotificationPermissionManager()
        let localNotificationService = LocalNotificationService()
        let mockNavigationProvider = MockNavigationProvider()
        let placesSearchService = ApplePlacesSearchService()
        let locationPermissionManager = LocationPermissionManager()
        let liveNavigationProvider = AppleNavigationProvider(
            preferencesProvider: { settings.routePreferences }
        )
        let miBandConnection = MiBandDirectConnection()
        let bandTransport = DirectMiBandTransport(
            scheduler: localNotificationService,
            directSender: miBandConnection,
            notificationsEnabled: { settings.bandNotificationsEnabled },
            soundEnabled: { settings.notificationSoundEnabled },
            speedLimitEnabled: { settings.showSpeedLimit },
            displayStyle: { settings.bandDisplayStyle }
        )
        let liveBandTransport = DirectMiBandTransport(
            scheduler: localNotificationService,
            directSender: miBandConnection,
            notificationsEnabled: { settings.bandNotificationsEnabled },
            soundEnabled: { settings.notificationSoundEnabled },
            speedLimitEnabled: { settings.showSpeedLimit },
            displayStyle: { settings.bandDisplayStyle }
        )

        self.settings = settings
        self.notificationPermissionManager = notificationPermissionManager
        self.localNotificationService = localNotificationService
        self.mockNavigationProvider = mockNavigationProvider
        self.placesSearchService = placesSearchService
        sharedLocationImporter = GoogleMapsLocationImporter(searchService: placesSearchService)
        self.locationPermissionManager = locationPermissionManager
        self.liveNavigationProvider = liveNavigationProvider
        self.miBandConnection = miBandConnection
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
