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
                        Label(mode.localizedName, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Tránh trạm thu phí", isOn: $settings.avoidTolls)
                Toggle("Tránh đường cao tốc", isOn: $settings.avoidHighways)
                Text("MapKit không có tùy chọn riêng để tránh cầu vượt. Các tùy chọn được áp dụng khi tính tuyến mới.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Bản đồ") {
                Picker("Kiểu bản đồ", selection: $settings.mapDisplayStyle) {
                    ForEach(MapDisplayStyle.allCases) { style in
                        Label(style.localizedName, systemImage: style.systemImage).tag(style)
                    }
                }
            }

            Section("Thông báo Mi Band") {
                Toggle("Bật thông báo điều hướng", isOn: $settings.bandNotificationsEnabled)
                Toggle("Âm thanh trên điện thoại", isOn: $settings.notificationSoundEnabled)
                LabeledContent("Quyền", value: permissionStatus.localizedDescription)
                Button("Cho phép thông báo") {
                    Task { await requestNotificationPermission() }
                }
            }

            Section("Khoảng cách cảnh báo") {
                Stepper(
                    "Xa: \(settings.farThresholdMeters) m",
                    value: $settings.farThresholdMeters,
                    in: 250...2_000,
                    step: 50
                )
                Stepper(
                    "Trung bình: \(settings.mediumThresholdMeters) m",
                    value: $settings.mediumThresholdMeters,
                    in: 100...1_000,
                    step: 50
                )
                Stepper(
                    "Gần: \(settings.nearThresholdMeters) m",
                    value: $settings.nearThresholdMeters,
                    in: 40...300,
                    step: 10
                )
                Stepper(
                    "Ngay lập tức: \(settings.immediateThresholdMeters) m",
                    value: $settings.immediateThresholdMeters,
                    in: 10...100,
                    step: 5
                )
                Text("Đơn vị: mét. Giá trị được áp dụng khi tạo tuyến tiếp theo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                NavigationLink("Pháp lý và quyền riêng tư") {
                    LegalView()
                }
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
