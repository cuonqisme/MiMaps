import Foundation

struct NavigationInstruction: Sendable, Equatable, Hashable {
    let maneuver: NavigationManeuver
    let roadName: String?
    let distanceToManeuverMeters: Double
    let remainingDistanceMeters: Double
    let remainingTimeSeconds: TimeInterval
    let stepIdentifier: String
    let timestamp: Date

    init(
        maneuver: NavigationManeuver,
        roadName: String?,
        distanceToManeuverMeters: Double,
        remainingDistanceMeters: Double,
        remainingTimeSeconds: TimeInterval,
        stepIdentifier: String,
        timestamp: Date = Date()
    ) {
        self.maneuver = maneuver
        self.roadName = roadName
        self.distanceToManeuverMeters = max(0, distanceToManeuverMeters)
        self.remainingDistanceMeters = max(0, remainingDistanceMeters)
        self.remainingTimeSeconds = max(0, remainingTimeSeconds)
        self.stepIdentifier = stepIdentifier
        self.timestamp = timestamp
    }

    func replacingDistanceToManeuver(with distance: Double) -> NavigationInstruction {
        NavigationInstruction(
            maneuver: maneuver,
            roadName: roadName,
            distanceToManeuverMeters: distance,
            remainingDistanceMeters: remainingDistanceMeters,
            remainingTimeSeconds: remainingTimeSeconds,
            stepIdentifier: stepIdentifier,
            timestamp: timestamp
        )
    }
}

