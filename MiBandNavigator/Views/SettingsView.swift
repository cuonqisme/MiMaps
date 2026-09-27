import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject private var settings: AppSettings
    private let permissionManager: NotificationPermissionManaging
    @ObservedObject private var locationPermissionManager: LocationPermissionManager
    @State private var permissionStatus: NotificationPermissionStatus = .notDetermined
    @State private var permissionError: String?

    init(environment: AppEnvironment) {
        _settings = ObservedObject(wrappedValue: environment.settings)
        permissionManager = environment.notificationPermissionManager
        _locationPermissionManager = ObservedObject(wrappedValue: environment.locationPermissionManager)
    }

    var body: some View {
        Form {
            Section("Phương tiện") {
                Picker("Chế độ di chuyển", selection: $settings.travelMode) {
                    ForEach(TravelMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Thông báo Mi Band") {
                Toggle("Bật thông báo điều hướng", isOn: $settings.bandNotificationsEnabled)
                Toggle("Âm thanh trên điện thoại", isOn: $settings.notificationSoundEnabled)
                LabeledContent("Quyền", value: permissionStatus.localizedDescription)
                Button("Cho phép thông báo") {
                    Task { await requestNotificationPermission() }
                }
            }

            Section("Vị trí và màn hình khóa") {
                LabeledContent("Quyền vị trí", value: locationPermissionManager.status.localizedDescription)
                Button("Cho phép vị trí nền") {
                    Task { _ = await locationPermissionManager.requestBackgroundAuthorization() }
                }
                Button("Mở Cài đặt iOS") { openSystemSettings() }
                Text("Vị trí nền chỉ hoạt động trong phiên chỉ đường và tự dừng khi dừng hoặc đến nơi.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Nhà phát triển") {
                Toggle("Chế độ nhà phát triển", isOn: $settings.developerModeEnabled)
            }

            Section("Giới thiệu") {
                LabeledContent("Phiên bản", value: appVersion)
                LabeledContent("Bản dựng", value: buildNumber)
                Text("MiBand Navigator không kết nối BLE riêng với Xiaomi Smart Band. Thông báo được chuyển tiếp bởi iOS và Mi Fitness.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let permissionError {
                Section("Lỗi") { Text(permissionError) }
            }
        }
        .navigationTitle("Cài đặt")
        .task { permissionStatus = await permissionManager.authorizationStatus() }
    }

    private func requestNotificationPermission() async {
        do {
            _ = try await permissionManager.requestAuthorization()
            permissionStatus = await permissionManager.authorizationStatus()
            permissionError = nil
        } catch {
            permissionError = error.localizedDescription
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
