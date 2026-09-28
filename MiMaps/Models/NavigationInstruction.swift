import Foundation

struct NavigationInstruction: Sendable, Equatable, Hashable {
    let maneuver: NavigationManeuver
    let roadName: String?
    let distanceToManeuverMeters: Double
    let remainingDistanceMeters: Double
    let remainingTimeSeconds: TimeInterval
    let stepIdentifier: String
    let timestamp: Date
    let currentSpeedKPH: Double?
    let speedLimitKPH: Double?
    let safetyAlert: NavigationSafetyAlert?

    init(
        maneuver: NavigationManeuver,
        roadName: String?,
        distanceToManeuverMeters: Double,
        remainingDistanceMeters: Double,
        remainingTimeSeconds: TimeInterval,
        stepIdentifier: String,
        timestamp: Date = Date(),
        currentSpeedKPH: Double? = nil,
        speedLimitKPH: Double? = nil,
        safetyAlert: NavigationSafetyAlert? = nil
    ) {
        self.maneuver = maneuver
        self.roadName = roadName
        self.distanceToManeuverMeters = max(0, distanceToManeuverMeters)
        self.remainingDistanceMeters = max(0, remainingDistanceMeters)
        self.remainingTimeSeconds = max(0, remainingTimeSeconds)
        self.stepIdentifier = stepIdentifier
        self.timestamp = timestamp
        self.currentSpeedKPH = currentSpeedKPH.map { max(0, $0) }
        self.speedLimitKPH = speedLimitKPH.map { max(0, $0) }
        self.safetyAlert = safetyAlert
    }
}
