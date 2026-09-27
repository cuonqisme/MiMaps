import Foundation

struct BandNotificationDecision: Sendable, Equatable {
    enum Reason: String, Sendable, Equatable {
        case thresholdCrossed
        case arrival
        case cooldown
        case noThresholdCrossing
        case duplicateArrival
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

    init(
        thresholds: [Int] = [500, 200, 80, 30],
        cooldownSeconds: TimeInterval = 2
    ) {
        self.thresholds = Array(Set(thresholds.filter { $0 > 0 })).sorted(by: >)
        self.cooldownSeconds = max(0, cooldownSeconds)
    }

    mutating func evaluate(_ instruction: NavigationInstruction) -> BandNotificationDecision {
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
    }
}
