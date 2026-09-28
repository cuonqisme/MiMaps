import XCTest
@testable import MiMaps

@MainActor
final class NavigationPermissionPreflightTests: XCTestCase {
    func testDeniedLocationBlocksNavigationAndDoesNotPromptForNotifications() async {
        let location = LocationPermissionSpy(status: .denied)
        let notifications = NotificationPermissionSpy(status: .denied)
        let preflight = NavigationPermissionPreflight(
            locationManager: location,
            notificationManager: notifications
        )

        let result = await preflight.prepare(notificationsRequired: true)

        XCTAssertFalse(result.canStartNavigation)
        XCTAssertTrue(result.shouldOfferSettings)
        XCTAssertEqual(notifications.requestCount, 0)
    }

    func testAuthorizedLocationRequestsBackgroundAndContextualNotifications() async {
        let location = LocationPermissionSpy(status: .authorizedWhenInUse)
        let notifications = NotificationPermissionSpy(
            status: .notDetermined,
            statusAfterRequest: .authorized
        )
        let preflight = NavigationPermissionPreflight(
            locationManager: location,
            notificationManager: notifications
        )

        let result = await preflight.prepare(notificationsRequired: true)

        XCTAssertTrue(result.canStartNavigation)
        XCTAssertEqual(location.backgroundRequestCount, 1)
        XCTAssertEqual(notifications.requestCount, 1)
        XCTAssertEqual(result.notificationStatus, .authorized)
        XCTAssertNotNil(result.warning)
    }

    func testDisabledBandNotificationsDoNotRequestNotificationPermission() async {
        let location = LocationPermissionSpy(status: .authorizedAlways)
        let notifications = NotificationPermissionSpy(status: .denied)
        let preflight = NavigationPermissionPreflight(
            locationManager: location,
            notificationManager: notifications
        )

        let result = await preflight.prepare(notificationsRequired: false)

        XCTAssertTrue(result.canStartNavigation)
        XCTAssertEqual(notifications.requestCount, 0)
        XCTAssertNil(result.warning)
        XCTAssertFalse(result.shouldOfferSettings)
    }
}

@MainActor
private final class LocationPermissionSpy: LocationPermissionManaging {
    private var status: LocationPermissionStatus
    private(set) var backgroundRequestCount = 0

    init(status: LocationPermissionStatus) {
        self.status = status
    }

    func requestWhenInUse() async -> LocationPermissionStatus { status }

    func requestBackgroundAuthorization() async -> LocationPermissionStatus {
        backgroundRequestCount += 1
        return status
    }

    func authorizationStatus() -> LocationPermissionStatus { status }
}

@MainActor
private final class NotificationPermissionSpy: NotificationPermissionManaging {
    private var status: NotificationPermissionStatus
    private let statusAfterRequest: NotificationPermissionStatus
    private(set) var requestCount = 0

    init(
        status: NotificationPermissionStatus,
        statusAfterRequest: NotificationPermissionStatus? = nil
    ) {
        self.status = status
        self.statusAfterRequest = statusAfterRequest ?? status
    }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        status = statusAfterRequest
        return status.allowsNotifications
    }

    func authorizationStatus() async -> NotificationPermissionStatus { status }
}
