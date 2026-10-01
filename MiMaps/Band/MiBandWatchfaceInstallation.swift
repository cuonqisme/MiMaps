import Foundation

enum MiBandWatchfaceInstallationState: Equatable, Sendable {
    case unavailable
    case awaitingDeviceInfo
    case ready
    case packageReady(identifier: String, byteCount: Int)
    case requestingInstall(identifier: String)
    case uploading(progressPercent: Int)
    case activating(identifier: String)
    case active(identifier: String)
    case restoring(identifier: String)
    case restored(identifier: String)
    case failed(String)

    var localizedDescription: String {
        switch self {
        case .unavailable: "chưa sẵn sàng"
        case .awaitingDeviceInfo: "đang đọc firmware, pin và mặt đồng hồ hiện tại"
        case .ready: "sẵn sàng tạo gói"
        case let .packageReady(identifier, byteCount):
            "gói \(identifier) hợp lệ (\(byteCount) byte)"
        case let .requestingInstall(identifier): "đang mở phiên cài \(identifier)"
        case let .uploading(progressPercent): "đang upload \(progressPercent)%"
        case let .activating(identifier): "đang kích hoạt \(identifier)"
        case let .active(identifier): "đang hiển thị \(identifier)"
        case let .restoring(identifier): "đang khôi phục \(identifier)"
        case let .restored(identifier): "đã khôi phục \(identifier)"
        case let .failed(message): "lỗi: \(message)"
        }
    }
}

enum MiBandWatchfaceSafetyError: LocalizedError, Equatable {
    case notConnected
    case firmwareUnknown
    case batteryUnknown
    case batteryTooLow(Int)
    case activeWatchfaceUnknown
    case packageMissing
    case riskNotAcknowledged

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Band chưa kết nối và xác thực."
        case .firmwareUnknown:
            "Chưa đọc được phiên bản firmware của Band."
        case .batteryUnknown:
            "Chưa đọc được mức pin của Band."
        case let .batteryTooLow(level):
            "Pin Band chỉ còn \(level)%; cần ít nhất 30%."
        case .activeWatchfaceUnknown:
            "Chưa lưu được ID mặt đồng hồ đang dùng để khôi phục."
        case .packageMissing:
            "Chưa có gói điều hướng đã kiểm tra."
        case .riskNotAcknowledged:
            "Cần xác nhận rủi ro firmware trước khi cài thử nghiệm."
        }
    }
}

struct MiBandWatchfaceSafetySnapshot: Equatable, Sendable {
    let isConnectedAndAuthenticated: Bool
    let firmwareVersion: String?
    let batteryLevel: Int?
    let previousWatchfaceIdentifier: String?
    let hasValidatedPackage: Bool
    let riskAcknowledged: Bool

    func validate() throws {
        guard isConnectedAndAuthenticated else {
            throw MiBandWatchfaceSafetyError.notConnected
        }
        guard let firmwareVersion, !firmwareVersion.isEmpty else {
            throw MiBandWatchfaceSafetyError.firmwareUnknown
        }
        guard let batteryLevel else {
            throw MiBandWatchfaceSafetyError.batteryUnknown
        }
        guard batteryLevel >= 30 else {
            throw MiBandWatchfaceSafetyError.batteryTooLow(batteryLevel)
        }
        guard let previousWatchfaceIdentifier,
              !previousWatchfaceIdentifier.isEmpty else {
            throw MiBandWatchfaceSafetyError.activeWatchfaceUnknown
        }
        guard hasValidatedPackage else {
            throw MiBandWatchfaceSafetyError.packageMissing
        }
        guard riskAcknowledged else {
            throw MiBandWatchfaceSafetyError.riskNotAcknowledged
        }
    }
}

struct MiBandWatchfaceRealtimePolicy: Equatable, Sendable {
    var minimumInterval: TimeInterval = 5
    var minimumDistanceChangeMeters = 5

    func shouldBuild(
        previousTimestamp: Date?,
        previousInstruction: NavigationInstruction?,
        next: NavigationInstruction
    ) -> Bool {
        guard let previousTimestamp, let previousInstruction else { return true }
        if previousInstruction.stepIdentifier != next.stepIdentifier
            || previousInstruction.maneuver != next.maneuver {
            return true
        }
        guard next.timestamp.timeIntervalSince(previousTimestamp) >= minimumInterval else {
            return false
        }
        return abs(
            previousInstruction.distanceToManeuverMeters
                - next.distanceToManeuverMeters
        ) >= Double(minimumDistanceChangeMeters)
    }
}
