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
}

