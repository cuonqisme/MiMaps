import Foundation

struct BandInstructionDeduplicator: Sendable {
    private struct Signature: Sendable, Hashable {
        let stepIdentifier: String
        let maneuver: NavigationManeuver
        let distanceMeters: Int
    }

    private var currentStepIdentifier: String?
    private var sentSignatures: Set<Signature> = []

    mutating func shouldSend(_ instruction: NavigationInstruction) -> Bool {
        if currentStepIdentifier != instruction.stepIdentifier {
            currentStepIdentifier = instruction.stepIdentifier
            sentSignatures.removeAll(keepingCapacity: true)
        }

        let signature = Signature(
            stepIdentifier: instruction.stepIdentifier,
            maneuver: instruction.maneuver,
            distanceMeters: Int(instruction.distanceToManeuverMeters.rounded())
        )
        return sentSignatures.insert(signature).inserted
    }

    mutating func reset() {
        currentStepIdentifier = nil
        sentSignatures.removeAll(keepingCapacity: true)
    }
}

