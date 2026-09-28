import XCTest
@testable import MiMaps

@MainActor
final class DeveloperToolsViewModelTests: XCTestCase {
    func testSelectedNotificationIsScheduledWithSoundPreference() async {
        let permission = PermissionManagerFake(status: .authorized)
        let scheduler = NotificationSchedulerSpy()
        let viewModel = DeveloperToolsViewModel(
            permissionManager: permission,
            scheduler: scheduler,
            soundEnabled: { true }
        )
        viewModel.selectedManeuver = .left
        viewModel.selectedDistance = 1_000
        viewModel.roadName = "Lê Thánh Tông"

        await viewModel.sendSelected()

        XCTAssertEqual(scheduler.contents, [
            NavigationNotificationContent(
                title: "← 1 km",
                body: "Lê Thánh Tông",
                categoryIdentifier: "NAVIGATION_MANEUVER",
                soundEnabled: true
            )
        ])
    }

    func testDestinationUsesArrivalBody() async {
        let scheduler = NotificationSchedulerSpy()
        let viewModel = DeveloperToolsViewModel(
            permissionManager: PermissionManagerFake(status: .authorized),
            scheduler: scheduler,
            soundEnabled: { false }
        )
        viewModel.selectedManeuver = .destination

        await viewModel.sendSelected()

        XCTAssertEqual(scheduler.contents.first?.body, "Đã đến nơi")
    }

    func testRefreshesPermissionStatus() async {
        let viewModel = DeveloperToolsViewModel(
            permissionManager: PermissionManagerFake(status: .denied),
            scheduler: NotificationSchedulerSpy(),
            soundEnabled: { false }
        )

        await viewModel.refreshPermissionStatus()

        XCTAssertEqual(viewModel.permissionStatus, .denied)
    }
}

@MainActor
private final class PermissionManagerFake: NotificationPermissionManaging {
    let status: NotificationPermissionStatus

    init(status: NotificationPermissionStatus) {
        self.status = status
    }

    func requestAuthorization() async throws -> Bool { status == .authorized }
    func authorizationStatus() async -> NotificationPermissionStatus { status }
}

@MainActor
private final class NotificationSchedulerSpy: LocalNotificationScheduling {
    private(set) var contents: [NavigationNotificationContent] = []

    func schedule(_ content: NavigationNotificationContent) async throws {
        contents.append(content)
    }
}
