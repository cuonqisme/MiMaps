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

