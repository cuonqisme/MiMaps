import Foundation

struct BandNotificationDecision: Sendable, Equatable {
    enum Reason: String, Sendable, Equatable {
        case thresholdCrossed
        case arrival
        case cooldown
        case noThresholdCrossing
        case duplicateArrival
        case safetyAlert
        case duplicateSafetyAlert
        case nonActionableManeuver
    }

    let notification: NavigationInstruction?
    let crossedThresholds: [Int]
    let reason: Reason
}

struct BandNotificationPolicy: Sendable {
    let thresholds: [Int]
    let cooldownSeconds: TimeInterval

    private(set) var currentStepIdentifier: String?
    private(set) var previousDistanceMeters: Double?
    private(set) var firedThresholds: Set<Int> = []
    private(set) var pendingThresholds: Set<Int> = []
    private(set) var lastNotificationTimestamp: Date?
    private var arrivalSent = false
    private var sentSafetyAlertIdentifiers: Set<String> = []

    init(
        thresholds: [Int] = [500, 200, 80, 30],
        cooldownSeconds: TimeInterval = 2
    ) {
        self.thresholds = Array(Set(thresholds.filter { $0 > 0 })).sorted(by: >)
        self.cooldownSeconds = max(0, cooldownSeconds)
    }

    mutating func evaluate(_ instruction: NavigationInstruction) -> BandNotificationDecision {
        if let alert = instruction.safetyAlert {
            guard sentSafetyAlertIdentifiers.insert(alert.identifier).inserted else {
                return BandNotificationDecision(
                    notification: nil,
                    crossedThresholds: [],
                    reason: .duplicateSafetyAlert
                )
            }
            lastNotificationTimestamp = instruction.timestamp
            return BandNotificationDecision(
                notification: instruction,
                crossedThresholds: [],
                reason: .safetyAlert
            )
        }

        let isNewStep = currentStepIdentifier != instruction.stepIdentifier
        if isNewStep {
            currentStepIdentifier = instruction.stepIdentifier
            previousDistanceMeters = .infinity
            firedThresholds.removeAll(keepingCapacity: true)
            pendingThresholds.removeAll(keepingCapacity: true)
            arrivalSent = false
        }

        if instruction.maneuver == .destination {
            previousDistanceMeters = instruction.distanceToManeuverMeters
            guard !arrivalSent else {
                return BandNotificationDecision(
                    notification: nil,
                    crossedThresholds: [],
                    reason: .duplicateArrival
                )
            }
            arrivalSent = true
            lastNotificationTimestamp = instruction.timestamp
            return BandNotificationDecision(
                notification: instruction,
                crossedThresholds: [],
                reason: .arrival
            )
        }

        if instruction.maneuver == .straight || instruction.maneuver == .unknown {
            previousDistanceMeters = instruction.distanceToManeuverMeters
            return BandNotificationDecision(
                notification: nil,
                crossedThresholds: [],
                reason: .nonActionableManeuver
            )
        }

        let previous = previousDistanceMeters ?? .infinity
        let current = instruction.distanceToManeuverMeters
        let newlyCrossed = thresholds.filter { threshold in
            !firedThresholds.contains(threshold)
                && !pendingThresholds.contains(threshold)
                && previous > Double(threshold)
                && current <= Double(threshold)
        }
        pendingThresholds.formUnion(newlyCrossed)
        previousDistanceMeters = current

        guard !pendingThresholds.isEmpty else {
            return BandNotificationDecision(
                notification: nil,
                crossedThresholds: newlyCrossed,
                reason: .noThresholdCrossing
            )
        }

        let cooldownElapsed = lastNotificationTimestamp.map {
            instruction.timestamp.timeIntervalSince($0) >= cooldownSeconds
        } ?? true
        guard isNewStep || cooldownElapsed else {
            return BandNotificationDecision(
                notification: nil,
                crossedThresholds: newlyCrossed,
                reason: .cooldown
            )
        }

        let batchedThresholds = pendingThresholds.sorted(by: >)
        let displayThreshold = batchedThresholds.min() ?? Int(current.rounded())
        firedThresholds.formUnion(pendingThresholds)
        pendingThresholds.removeAll(keepingCapacity: true)
        lastNotificationTimestamp = instruction.timestamp

        return BandNotificationDecision(
            notification: instruction.replacingDistanceToManeuver(with: Double(displayThreshold)),
            crossedThresholds: batchedThresholds,
            reason: .thresholdCrossed
        )
    }

    mutating func reset() {
        currentStepIdentifier = nil
        previousDistanceMeters = nil
        firedThresholds.removeAll(keepingCapacity: true)
        pendingThresholds.removeAll(keepingCapacity: true)
        lastNotificationTimestamp = nil
        arrivalSent = false
        sentSafetyAlertIdentifiers.removeAll(keepingCapacity: true)
    }
}
