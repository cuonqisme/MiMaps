import Foundation

struct RouteOptionSummary: Identifiable, Sendable, Equatable, Hashable {
    let id: Int
    let name: String
    let distanceMeters: Double
    let expectedTravelTimeSeconds: TimeInterval
    let advantages: [String]
    let disadvantages: [String]
    let hasTolls: Bool
    let hasHighways: Bool
}
