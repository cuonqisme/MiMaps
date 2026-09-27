import GoogleMaps
import GooglePlacesSwift
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
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
        UNUserNotificationCenter.current().setNotificationCategories([category])
        return true
    }
}
