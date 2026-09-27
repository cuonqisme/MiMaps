import SwiftUI

struct DeveloperToolsView: View {
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: DeveloperToolsViewModel

    init(environment: AppEnvironment) {
        _settings = ObservedObject(wrappedValue: environment.settings)
        _viewModel = StateObject(
            wrappedValue: DeveloperToolsViewModel(
                permissionManager: environment.notificationPermissionManager,
                scheduler: environment.localNotificationService,
                soundEnabled: { environment.settings.notificationSoundEnabled }
            )
        )
    }

    var body: some View {
        Form {
            Section("Quyền thông báo") {
                LabeledContent("Trạng thái", value: viewModel.permissionStatus.localizedDescription)
                Button("Cho phép thông báo") {
                    Task { await viewModel.requestPermission() }
                }
            }

            Section("Test Mi Band Notifications") {
                Picker("Hướng", selection: $viewModel.selectedManeuver) {
                    ForEach(TestManeuver.allCases) { maneuver in
                        Text("\(maneuver.symbol) \(maneuver.label)").tag(maneuver)
                    }
                }

                Picker("Khoảng cách", selection: $viewModel.selectedDistance) {
                    ForEach(DeveloperToolsViewModel.testDistances, id: \.self) { distance in
                        Text(DeveloperToolsViewModel.format(distanceMeters: distance)).tag(distance)
                    }
                }

                TextField("Tên đường", text: $viewModel.roadName)
                    .textInputAutocapitalization(.words)

                Button("GỬI THÔNG BÁO THỬ") {
                    Task { await viewModel.sendSelected() }
                }
                .buttonStyle(.borderedProminent)

                Button("GỬI TẤT CẢ BIỂU TƯỢNG TUẦN TỰ") {
                    Task { await viewModel.sendAllSymbols() }
                }
                .disabled(viewModel.isSendingSequence)

                if viewModel.isSendingSequence {
                    ProgressView("Đang gửi cách nhau 3 giây…")
                }
            }

            if !viewModel.feedback.isEmpty {
                Section("Kết quả") {
                    Text(viewModel.feedback)
                        .textSelection(.enabled)
                }
            }

            Section {
                Text("Mi Band nhận thông báo thông qua cơ chế phản chiếu của iOS/Mi Fitness. Ứng dụng không điều khiển kiểu rung của thiết bị.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Công cụ nhà phát triển")
        .task { await viewModel.refreshPermissionStatus() }
    }
}

