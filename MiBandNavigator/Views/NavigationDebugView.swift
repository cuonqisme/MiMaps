import SwiftUI

struct NavigationDebugView: View {
    @ObservedObject var coordinator: NavigationCoordinator
    @ObservedObject var mockProvider: MockNavigationProvider
    let permissionManager: NotificationPermissionManaging
    @State private var notificationStatus: NotificationPermissionStatus = .notDetermined

    var body: some View {
        List {
            debugRow("Phiên bản", appVersion)
            debugRow("Bản dựng", buildNumber)
            debugRow("Môi trường", "Debug / Mock")
            debugRow("Nhà cung cấp", coordinator.provider.providerName)
            debugRow("Trạng thái", String(describing: coordinator.state))
            debugRow("Tốc độ mô phỏng", String(format: "%.2gx", mockProvider.speedMultiplier))
            debugRow("Tạm dừng", mockProvider.isPaused ? "Có" : "Không")
            debugRow("Quyền thông báo", notificationStatus.localizedDescription)
            debugRow("Ngưỡng", "500, 200, 80, 30 m")
            debugRow("Đã gửi", coordinator.firedThresholds.sorted(by: >).map(String.init).joined(separator: ", "))

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
}

