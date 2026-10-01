import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject private var settings: AppSettings
    private let permissionManager: NotificationPermissionManaging
    @ObservedObject private var locationPermissionManager: LocationPermissionManager
    @ObservedObject private var miBandConnection: MiBandDirectConnection
    @State private var permissionStatus: NotificationPermissionStatus = .notDetermined
    @State private var permissionError: String?

    init(environment: AppEnvironment) {
        _settings = ObservedObject(wrappedValue: environment.settings)
        permissionManager = environment.notificationPermissionManager
        _locationPermissionManager = ObservedObject(wrappedValue: environment.locationPermissionManager)
        _miBandConnection = ObservedObject(wrappedValue: environment.miBandConnection)
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
                Toggle("Hiển thị giao thông trực tiếp", isOn: $settings.showTraffic)
                Text("Mức độ phủ sóng giao thông phụ thuộc dữ liệu Apple Maps tại khu vực hiện tại.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Thông báo Mi Band") {
                NavigationLink {
                    BandConnectionView(connection: miBandConnection)
                } label: {
                    LabeledContent("Kết nối Mi Band 8", value: miBandConnection.state.localizedDescription)
                }
                Toggle("Bật thông báo điều hướng", isOn: $settings.bandNotificationsEnabled)
                Toggle("Cập nhật khoảng cách realtime trên Band", isOn: $settings.bandLiveUpdatesEnabled)
                Text("Khi kết nối trực tiếp, MiMaps cập nhật cùng một thẻ điều hướng tối đa mỗi 2 giây. Một số firmware có thể rung mỗi lần cập nhật và dùng pin nhiều hơn.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Âm thanh trên điện thoại", isOn: $settings.notificationSoundEnabled)
                Picker("Kiểu hiển thị", selection: $settings.bandDisplayStyle) {
                    ForEach(BandDisplayStyle.allCases) { style in
                        Text(style.localizedName).tag(style)
                    }
                }
                .pickerStyle(.menu)
                Text(settings.bandDisplayStyle.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Hiển thị giới hạn tốc độ", isOn: $settings.showSpeedLimit)
                Text("Chỉ hiển thị khi nguồn dữ liệu tuyến đường cung cấp giới hạn tốc độ. Apple MapKit hiện không cung cấp dữ liệu này qua API công khai.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LabeledContent("Quyền", value: permissionStatus.localizedDescription)
                Button("Cho phép thông báo") {
                    Task { await requestNotificationPermission() }
                }
                Text("Band Lab kết nối Bluetooth trực tiếp, lưu khóa ghép đôi trong Keychain và thu dữ liệu giao thức. Thông báo điều hướng vẫn chỉ xuất hiện trên iPhone cho đến khi bước xác thực hoàn tất.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                Text("MiMaps đang triển khai companion Bluetooth trực tiếp cho Xiaomi Smart Band 8. Mi Fitness chỉ cần tạm thời để lấy khóa ghép đôi hiện có; MiMaps không dùng Mi Fitness khi vận hành.")
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
