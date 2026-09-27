import Foundation
import GoogleNavigation

struct GoogleManeuverMapper: Sendable {
    func map(
        _ maneuver: GMSNavigationManeuver,
        roundaboutTurnNumber: Int = -1
    ) -> NavigationManeuver {
        map(rawValue: maneuver.rawValue, roundaboutTurnNumber: roundaboutTurnNumber)
    }

    func map(
        rawValue: UInt,
        roundaboutTurnNumber: Int = -1
    ) -> NavigationManeuver {
        switch rawValue {
        case 1, 5, 63...65:
            .straight
        case 2...4:
            .destination
        case 6:
            .left
        case 7:
            .right
        case 8:
            .forkLeft
        case 9:
            .forkRight
        case 10:
            .slightLeft
        case 11:
            .slightRight
        case 12:
            .sharpLeft
        case 13:
            .sharpRight
        case 14, 30, 41:
            .uTurnRight
        case 15, 31, 42:
            .uTurnLeft
        case 16:
            .straight
        case 17:
            .mergeLeft
        case 18:
            .mergeRight
        case 19:
            .forkLeft
        case 20:
            .forkRight
        case 22, 24, 26, 28, 33, 35, 37, 39:
            .rampLeft
        case 23, 25, 27, 29, 34, 36, 38, 40:
            .rampRight
        case 43...62:
            roundaboutTurnNumber > 0 ? .roundaboutExit(roundaboutTurnNumber) : .roundabout
        default:
            .unknown
        }
    }
}

struct GoogleNavigationFeedSnapshot: Sendable, Equatable {
    let maneuverRawValue: UInt
    let roundaboutTurnNumber: Int
    let routeRevision: Int
    let stepNumber: Int
    let roadName: String
    let distanceToManeuverMeters: Double
    let remainingDistanceMeters: Double
    let remainingTimeSeconds: TimeInterval
}

struct GoogleNavigationInstructionFactory: Sendable {
    private let maneuverMapper = GoogleManeuverMapper()

    func makeInstruction(
        from snapshot: GoogleNavigationFeedSnapshot,
        timestamp: Date = Date()
    ) -> NavigationInstruction {
        let normalizedRoadName = snapshot.roadName.trimmingCharacters(in: .whitespacesAndNewlines)
        return NavigationInstruction(
            maneuver: maneuverMapper.map(
                rawValue: snapshot.maneuverRawValue,
                roundaboutTurnNumber: snapshot.roundaboutTurnNumber
            ),
            roadName: normalizedRoadName.isEmpty ? nil : normalizedRoadName,
            distanceToManeuverMeters: snapshot.distanceToManeuverMeters,
            remainingDistanceMeters: snapshot.remainingDistanceMeters,
            remainingTimeSeconds: snapshot.remainingTimeSeconds,
            stepIdentifier: "google-route-\(snapshot.routeRevision)-step-\(snapshot.stepNumber)",
            timestamp: timestamp
        )
    }
}
