import Foundation

enum NavigationSafetyAlertKind: String, Sendable, Equatable, Hashable {
    case fixedSpeedCamera
    case mobileSpeedCamera
    case redLightCamera
    case averageSpeedZone
    case speeding
    case hazard

    var localizedName: String {
        switch self {
        case .fixedSpeedCamera: "Camera tốc độ"
        case .mobileSpeedCamera: "Camera lưu động"
        case .redLightCamera: "Camera đèn đỏ"
        case .averageSpeedZone: "Đo tốc độ trung bình"
        case .speeding: "Vượt tốc độ"
        case .hazard: "Cảnh báo đường"
        }
    }
}

struct NavigationSafetyAlert: Sendable, Equatable, Hashable {
    let identifier: String
    let kind: NavigationSafetyAlertKind
    let distanceMeters: Double
    let speedLimitKPH: Double?

    init(
        identifier: String,
        kind: NavigationSafetyAlertKind,
        distanceMeters: Double,
        speedLimitKPH: Double? = nil
    ) {
        self.identifier = identifier
        self.kind = kind
        self.distanceMeters = max(0, distanceMeters)
        self.speedLimitKPH = speedLimitKPH
    }
}
