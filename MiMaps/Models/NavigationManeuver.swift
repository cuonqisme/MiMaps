import Foundation

enum NavigationManeuver: Sendable, Equatable, Hashable {
    case straight
    case slightLeft
    case left
    case sharpLeft
    case slightRight
    case right
    case sharpRight
    case uTurnLeft
    case uTurnRight
    case mergeLeft
    case mergeRight
    case forkLeft
    case forkRight
    case rampLeft
    case rampRight
    case roundabout
    case roundaboutExit(Int?)
    case destination
    case unknown
}

enum ManeuverSymbolKey: String, Sendable, CaseIterable, Hashable {
    case straight
    case slightLeft
    case left
    case sharpLeft
    case slightRight
    case right
    case sharpRight
    case uTurnLeft
    case uTurnRight
    case mergeLeft
    case mergeRight
    case forkLeft
    case forkRight
    case rampLeft
    case rampRight
    case roundabout
    case destination
    case unknown
}

extension NavigationManeuver {
    func conciseInstruction(roadName: String?) -> String {
        let action: String = switch self {
        case .straight: "Đi thẳng"
        case .slightLeft: "Lệch trái"
        case .left: "Rẽ trái"
        case .sharpLeft: "Rẽ gấp trái"
        case .slightRight: "Lệch phải"
        case .right: "Rẽ phải"
        case .sharpRight: "Rẽ gấp phải"
        case .uTurnLeft: "Quay đầu trái"
        case .uTurnRight: "Quay đầu phải"
        case .mergeLeft: "Nhập làn trái"
        case .mergeRight: "Nhập làn phải"
        case .forkLeft: "Theo nhánh trái"
        case .forkRight: "Theo nhánh phải"
        case .rampLeft: "Ra lối trái"
        case .rampRight: "Ra lối phải"
        case .roundabout: "Vào vòng xuyến"
        case let .roundaboutExit(exit): exit.map { "Vòng xuyến · lối ra \($0)" } ?? "Ra khỏi vòng xuyến"
        case .destination: "Đã đến nơi"
        case .unknown: "Tiếp tục theo tuyến"
        }
        guard let roadName = roadName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !roadName.isEmpty else { return action }
        return "\(action) · \(String(roadName.prefix(48)))"
    }

    var symbolKey: ManeuverSymbolKey {
        switch self {
        case .straight: .straight
        case .slightLeft: .slightLeft
        case .left: .left
        case .sharpLeft: .sharpLeft
        case .slightRight: .slightRight
        case .right: .right
        case .sharpRight: .sharpRight
        case .uTurnLeft: .uTurnLeft
        case .uTurnRight: .uTurnRight
        case .mergeLeft: .mergeLeft
        case .mergeRight: .mergeRight
        case .forkLeft: .forkLeft
        case .forkRight: .forkRight
        case .rampLeft: .rampLeft
        case .rampRight: .rampRight
        case .roundabout, .roundaboutExit: .roundabout
        case .destination: .destination
        case .unknown: .unknown
        }
    }

    var phoneSystemImage: String {
        switch self {
        case .straight: "arrow.up"
        case .slightLeft: "arrow.up.left"
        case .left, .sharpLeft: "arrow.turn.up.left"
        case .slightRight: "arrow.up.right"
        case .right, .sharpRight: "arrow.turn.up.right"
        case .uTurnLeft: "arrow.uturn.left"
        case .uTurnRight: "arrow.uturn.right"
        case .mergeLeft, .forkLeft, .rampLeft: "arrow.up.left"
        case .mergeRight, .forkRight, .rampRight: "arrow.up.right"
        case .roundabout, .roundaboutExit: "arrow.clockwise.circle.fill"
        case .destination: "flag.fill"
        case .unknown: "location.north.fill"
        }
    }
}
