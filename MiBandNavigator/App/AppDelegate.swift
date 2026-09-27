import GoogleMaps
import GooglePlacesSwift
import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, @MainActor UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let apiKey = AppConfig.googleMapsAPIKey {
            GMSServices.provideAPIKey(apiKey)
            _ = PlacesClient.provideAPIKey(apiKey)
        }

        let category = UNNotificationCategory(
            identifier: LocalNotificationService.navigationCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        notificationCenter.setNotificationCategories([category])
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        _ = center
        _ = notification
        return [.banner, .list]
    }
}
