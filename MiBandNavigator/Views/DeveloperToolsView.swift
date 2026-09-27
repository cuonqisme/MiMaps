import Foundation
import SwiftUI

struct DeveloperToolsView: View {
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var coordinator: NavigationCoordinator
    @ObservedObject private var mockProvider: MockNavigationProvider
    @ObservedObject private var googleCoordinator: NavigationCoordinator
    @ObservedObject private var googleProvider: GoogleNavigationProvider
    @StateObject private var viewModel: DeveloperToolsViewModel

    init(environment: AppEnvironment) {
        _settings = ObservedObject(wrappedValue: environment.settings)
        _coordinator = ObservedObject(wrappedValue: environment.navigationCoordinator)
        _mockProvider = ObservedObject(wrappedValue: environment.mockNavigationProvider)
        _googleCoordinator = ObservedObject(wrappedValue: environment.googleNavigationCoordinator)
        _googleProvider = ObservedObject(wrappedValue: environment.googleNavigationProvider)
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
            Section("Google Navigation") {
                LabeledContent("Trạng thái", value: String(describing: googleCoordinator.state))
                LabeledContent("Yêu cầu", value: googleProvider.requestedTravelMode.localizedName)
                LabeledContent("Đang dùng", value: googleProvider.activeTravelMode.localizedName)
                LabeledContent("Fallback ô tô", value: googleProvider.fallbackUsed ? "Có" : "Không")
                LabeledContent("Phiên bản tuyến", value: String(googleProvider.routeRevision))

                if let instruction = googleCoordinator.currentInstruction {
                    Text("\(BandNotificationFormatter().symbol(for: instruction.maneuver)) \(DistanceFormatter.string(fromMeters: instruction.distanceToManeuverMeters)) — \(instruction.roadName ?? "—")")
                        .font(.headline)
                }
            }

            Section("Mock Navigation") {
                LabeledContent("Trạng thái", value: String(describing: coordinator.state))
                LabeledContent("Tốc độ", value: String(format: "%.2gx", mockProvider.speedMultiplier))

                Button("BẮT ĐẦU TUYẾN MÔ PHỎNG") {
                    Task { await coordinator.startMockRoute() }
                }
                .buttonStyle(.borderedProminent)

                HStack {
                    Button("Tạm dừng") { mockProvider.pause() }
                    Button("Tiếp tục") { mockProvider.resume() }
                }
                HStack {
                    Button("Nhanh hơn") { mockProvider.speedUp() }
                    Button("Chậm hơn") { mockProvider.slowDown() }
                }
                Button("Chuyển chặng tiếp theo") { mockProvider.nextManeuver() }
                Button("Đặt lại", role: .destructive) { mockProvider.reset() }

                if let instruction = coordinator.currentInstruction {
                    Text("\(BandNotificationFormatter().symbol(for: instruction.maneuver)) \(DistanceFormatter.string(fromMeters: instruction.distanceToManeuverMeters)) — \(instruction.roadName ?? "—")")
                        .font(.headline)
                }

                NavigationLink("Mở bảng gỡ lỗi") {
                    NavigationDebugView(
                        coordinator: coordinator,
                        mockProvider: mockProvider,
                        permissionManager: viewModel.permissionManagerForDebug
                    )
                }
            }

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
