import Combine
import Foundation

enum TestManeuver: String, CaseIterable, Identifiable, Sendable {
    case straight
    case slightLeft
    case left
    case sharpLeft
    case slightRight
    case right
    case sharpRight
    case uTurnLeft
    case uTurnRight
    case roundabout
    case destination

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .straight: "↑"
        case .slightLeft: "↖"
        case .left: "←"
        case .sharpLeft: "↰"
        case .slightRight: "↗"
        case .right: "→"
        case .sharpRight: "↱"
        case .uTurnLeft: "↶"
        case .uTurnRight: "↷"
        case .roundabout: "⟳"
        case .destination: "●"
        }
    }

    var label: String {
        switch self {
        case .straight: "Đi thẳng"
        case .slightLeft: "Chếch trái"
        case .left: "Rẽ trái"
        case .sharpLeft: "Rẽ gấp trái"
        case .slightRight: "Chếch phải"
        case .right: "Rẽ phải"
        case .sharpRight: "Rẽ gấp phải"
        case .uTurnLeft: "Quay đầu trái"
        case .uTurnRight: "Quay đầu phải"
        case .roundabout: "Vòng xuyến"
        case .destination: "Đã đến nơi"
        }
    }
}

@MainActor
final class DeveloperToolsViewModel: ObservableObject {
    static let testDistances = [30, 80, 200, 500, 1_000, 2_000]

    @Published var selectedManeuver: TestManeuver = .right
    @Published var selectedDistance = 200
    @Published var roadName = "Trần Phú"
    @Published private(set) var permissionStatus: NotificationPermissionStatus = .notDetermined
    @Published private(set) var feedback = ""
    @Published private(set) var isSendingSequence = false

    private let permissionManager: NotificationPermissionManaging
    private let scheduler: LocalNotificationScheduling
    private let soundEnabled: () -> Bool

    init(
        permissionManager: NotificationPermissionManaging,
        scheduler: LocalNotificationScheduling,
        soundEnabled: @escaping () -> Bool
    ) {
        self.permissionManager = permissionManager
        self.scheduler = scheduler
        self.soundEnabled = soundEnabled
    }

    func refreshPermissionStatus() async {
        permissionStatus = await permissionManager.authorizationStatus()
    }

    func requestPermission() async {
        do {
            let granted = try await permissionManager.requestAuthorization()
            await refreshPermissionStatus()
            feedback = granted ? "Đã cho phép thông báo." : "Thông báo chưa được cho phép."
        } catch {
            feedback = "Không thể yêu cầu quyền: \(error.localizedDescription)"
        }
    }

    func sendSelected() async {
        await send(maneuver: selectedManeuver)
    }

    func sendAllSymbols(delayNanoseconds: UInt64 = 3_000_000_000) async {
        guard !isSendingSequence else { return }
        isSendingSequence = true
        defer { isSendingSequence = false }

        for (index, maneuver) in TestManeuver.allCases.enumerated() {
            await send(maneuver: maneuver)
            guard index < TestManeuver.allCases.count - 1 else { continue }
            do {
                try await Task.sleep(for: .nanoseconds(Int64(clamping: delayNanoseconds)))
            } catch {
                feedback = "Đã dừng chuỗi kiểm tra."
                return
            }
        }
    }

    private func send(maneuver: TestManeuver) async {
        let content = NotificationContentFactory.make(
            symbol: maneuver.symbol,
            distanceText: Self.format(distanceMeters: selectedDistance),
            roadName: maneuver == .destination ? "Đã đến nơi" : roadName,
            soundEnabled: soundEnabled()
        )

        do {
            try await scheduler.schedule(content)
            feedback = "Đã gửi: \(content.title)"
        } catch {
            feedback = "Gửi thông báo thất bại: \(error.localizedDescription)"
        }
    }

    static func format(distanceMeters: Int) -> String {
        if distanceMeters >= 1_000, distanceMeters.isMultiple(of: 1_000) {
            return "\(distanceMeters / 1_000) km"
        }
        return "\(distanceMeters) m"
    }
}
