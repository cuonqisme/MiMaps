import Foundation

struct MiBandDevice: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let rssi: Int
    let isSupportedModel: Bool
}

enum MiBandConnectionState: Equatable, Sendable {
    case idle
    case bluetoothUnavailable(String)
    case scanning
    case connecting(String)
    case discovering(String)
    case ready(String)
    case disconnected
    case failed(String)

    var localizedDescription: String {
        switch self {
        case .idle:
            "Sẵn sàng"
        case let .bluetoothUnavailable(reason):
            "Bluetooth: \(reason)"
        case .scanning:
            "Đang tìm Mi Band 8…"
        case let .connecting(name):
            "Đang kết nối \(name)…"
        case let .discovering(name):
            "Đang đọc cấu hình \(name)…"
        case let .ready(name):
            "Đã kết nối \(name)"
        case .disconnected:
            "Đã ngắt kết nối"
        case let .failed(message):
            "Lỗi: \(message)"
        }
    }

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

enum MiBandAuthenticationState: Equatable, Sendable {
    case missingKey
    case ready
    case subscribing
    case waitingForWatch
    case verifying
    case authenticated
    case failed(String)

    var localizedDescription: String {
        switch self {
        case .missingKey: "Chưa cấu hình khóa"
        case .ready: "Sẵn sàng xác thực"
        case .subscribing: "Đang mở kênh bảo mật…"
        case .waitingForWatch: "Đang chờ phản hồi từ vòng…"
        case .verifying: "Đang kiểm tra khóa…"
        case .authenticated: "Đã xác thực trực tiếp"
        case let .failed(message): "Lỗi: \(message)"
        }
    }

    var isInProgress: Bool {
        switch self {
        case .subscribing, .waitingForWatch, .verifying: true
        default: false
        }
    }
}

enum MiBandDirectNotificationState: Equatable, Sendable {
    case unavailable
    case ready
    case sending(String)
    case delivered(String)
    case failed(String)

    var localizedDescription: String {
        switch self {
        case .unavailable: "Chưa sẵn sàng"
        case .ready: "Sẵn sàng gửi trực tiếp"
        case let .sending(label): "Đang gửi: \(label)"
        case let .delivered(label): "Band đã nhận: \(label)"
        case let .failed(message): "Lỗi: \(message)"
        }
    }
}

enum MiBandDeviceMatcher {
    static func isMiBand8(name: String?) -> Bool {
        guard let normalized = name?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else {
            return false
        }

        return normalized.contains("smart band 8")
            || normalized.contains("mi band 8")
            || normalized.contains("band8")
            || normalized.contains("band 8")
    }
}

struct MiBandGATTCharacteristic: Equatable, Sendable {
    let serviceUUID: String
    let characteristicUUID: String
    let properties: [String]
}

struct MiBandCapturedPacket: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let serviceUUID: String
    let characteristicUUID: String
    let byteCount: Int
    let hexPreview: String

    init(
        id: UUID = UUID(),
        timestamp: Date,
        serviceUUID: String,
        characteristicUUID: String,
        data: Data
    ) {
        self.id = id
        self.timestamp = timestamp
        self.serviceUUID = serviceUUID
        self.characteristicUUID = characteristicUUID
        byteCount = data.count
        hexPreview = Self.preview(data)
    }

    static func preview(_ data: Data, limit: Int = 64) -> String {
        let visible = data.prefix(max(0, limit))
        let value = visible.map { String(format: "%02X", $0) }.joined()
        return data.count > visible.count ? value + "…" : value
    }
}
