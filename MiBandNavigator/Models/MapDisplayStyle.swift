import Foundation

enum MapDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case standard
    case muted
    case satellite
    case hybrid

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .standard: "Tiêu chuẩn"
        case .muted: "Tối giản"
        case .satellite: "Vệ tinh"
        case .hybrid: "Kết hợp"
        }
    }

    var systemImage: String {
        switch self {
        case .standard: "map"
        case .muted: "map.fill"
        case .satellite: "globe.asia.australia.fill"
        case .hybrid: "square.3.layers.3d"
        }
    }
}
