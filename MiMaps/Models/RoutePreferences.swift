import Foundation

struct RoutePreferences: Sendable, Equatable {
    var avoidTolls: Bool
    var avoidHighways: Bool

    static let standard = RoutePreferences(avoidTolls: false, avoidHighways: false)
}
