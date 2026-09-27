import Foundation
import SwiftUI

struct NavigationDebugView: View {
    @ObservedObject var coordinator: NavigationCoordinator
    @ObservedObject var navigationProvider: AppleNavigationProvider
    @ObservedObject var locationPermissionManager: LocationPermissionManager
    @ObservedObject var settings: AppSettings
    let permissionManager: NotificationPermissionManaging
    @State private var notificationStatus: NotificationPermissionStatus = .notDetermined

    init(
        coordinator: NavigationCoordinator,
        navigationProvider: AppleNavigationProvider,
        locationPermissionManager: LocationPermissionManager,
        settings: AppSettings,
        permissionManager: NotificationPermissionManaging
    ) {
        _coordinator = ObservedObject(wrappedValue: coordinator)
        _navigationProvider = ObservedObject(wrappedValue: navigationProvider)
        _locationPermissionManager = ObservedObject(wrappedValue: locationPermissionManager)
        _settings = ObservedObject(wrappedValue: settings)
        self.permissionManager = permissionManager
    }

    var body: some View {
        List {
            Section("Ứng dụng") {
                debugRow("Phiên bản", appVersion)
                debugRow("Bản dựng", buildNumber)
                debugRow("Môi trường", buildConfiguration)
                debugRow("Nhà cung cấp", coordinator.provider.providerName)
                debugRow("Bản đồ", "Apple MapKit (native)")
                debugRow("API key", "Không yêu cầu")
            }

            Section("Phiên điều hướng") {
                debugRow("Phương tiện yêu cầu", navigationProvider.requestedTravelMode.localizedName)
                debugRow("Phương tiện đang dùng", navigationProvider.activeTravelMode.localizedName)
                debugRow("Fallback ô tô", navigationProvider.fallbackUsed ? "Có" : "Không")
                debugRow("Trạng thái", String(describing: coordinator.state))
                debugRow("Phiên bản tuyến", String(navigationProvider.routeRevision))
                debugRow("Số lần đổi tuyến", String(navigationProvider.routeChangeCount))
                debugRow("Số lần định tuyến lại", String(navigationProvider.rerouteCount))
                debugRow("Chỉ dẫn MapKit", navigationProvider.lastInstructionText ?? "—")
            }

            Section("Vị trí hiện tại trong bộ nhớ") {
                debugRow("Vĩ độ", coordinate(navigationProvider.lastLatitude))
                debugRow("Kinh độ", coordinate(navigationProvider.lastLongitude))
                debugRow("Tốc độ", speed(navigationProvider.lastSpeedMetersPerSecond))
                debugRow("Hướng", course(navigationProvider.lastCourseDegrees))
                debugRow("Cập nhật cuối", navigationProvider.lastLocationUpdateAt?.formatted() ?? "—")
                debugRow("Cập nhật nền", navigationProvider.backgroundUpdatesActive ? "Đang chạy" : "Đã dừng")
                Text("Ảnh chụp vị trí chỉ giữ trong bộ nhớ khi đang điều hướng; không ghi lịch sử tọa độ.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Thông báo và quyền") {
                debugRow("Ngưỡng cấu hình", meters(coordinator.configuredThresholds))
                debugRow("Ngưỡng đã gửi", meters(coordinator.firedThresholds.sorted(by: >)))
                debugRow("Quyền thông báo", notificationStatus.localizedDescription)
                debugRow("Quyền vị trí", locationPermissionManager.status.localizedDescription)
                debugRow("Thông báo Mi Band", settings.bandNotificationsEnabled ? "Bật" : "Tắt")
                debugRow("Âm thanh", settings.notificationSoundEnabled ? "Bật" : "Tắt")
            }

            if let instruction = coordinator.currentInstruction {
                Section("Chỉ dẫn hiện tại") {
                    debugRow("Step ID", instruction.stepIdentifier)
                    debugRow("Maneuver", String(describing: instruction.maneuver))
                    debugRow("Biểu tượng", BandNotificationFormatter().symbol(for: instruction.maneuver))
                    debugRow("Tên đường", instruction.roadName ?? "—")
                    debugRow("Khoảng cách đến chặng", DistanceFormatter.string(fromMeters: instruction.distanceToManeuverMeters))
                    debugRow("Quãng đường còn lại", DistanceFormatter.string(fromMeters: instruction.remainingDistanceMeters))
                    debugRow("Thời gian còn lại", DurationFormatter.string(fromSeconds: instruction.remainingTimeSeconds))
                }
            }

            if let notification = coordinator.lastBandNotification {
                Section("Thông báo gần nhất") {
                    debugRow("Step ID", notification.stepIdentifier)
                    debugRow("Khoảng cách", DistanceFormatter.string(fromMeters: notification.distanceToManeuverMeters))
                    debugRow("Thời gian", notification.timestamp.formatted())
                }
            }

            if let error = coordinator.lastError {
                Section("Lỗi gần nhất") { Text(error).textSelection(.enabled) }
            }
        }
        .navigationTitle("Navigation Debug")
        .task { notificationStatus = await permissionManager.authorizationStatus() }
    }

    @ViewBuilder
    private func debugRow(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value.isEmpty ? "—" : value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var buildConfiguration: String {
        #if DEBUG
        "Debug"
        #else
        "Release"
        #endif
    }

    private func coordinate(_ value: Double?) -> String {
        value.map { String(format: "%.6f", $0) } ?? "—"
    }

    private func speed(_ value: Double?) -> String {
        value.map { String(format: "%.1f m/s", $0) } ?? "—"
    }

    private func course(_ value: Double?) -> String {
        value.map { String(format: "%.0f°", $0) } ?? "—"
    }

    private func meters<S: Sequence>(_ values: S) -> String where S.Element == Int {
        let value = values.map { "\($0) m" }.joined(separator: ", ")
        return value.isEmpty ? "—" : value
    }
}
