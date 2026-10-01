import Foundation

@MainActor
protocol MiBandDirectNotificationSending: AnyObject {
    var canSendDirectNotifications: Bool { get }
    func sendDirectNotification(
        title: String,
        body: String,
        label: String,
        maneuver: NavigationManeuver?
    )
    func sendNavigationInstruction(
        _ instruction: NavigationInstruction,
        title: String,
        body: String,
        label: String
    )
    func stopFullscreenNavigation()
}

extension MiBandDirectNotificationSending {
    func sendNavigationInstruction(
        _ instruction: NavigationInstruction,
        title: String,
        body: String,
        label: String
    ) {
        sendDirectNotification(
            title: title,
            body: body,
            label: label,
            maneuver: instruction.maneuver
        )
    }

    func stopFullscreenNavigation() {}
}

extension MiBandDirectConnection: MiBandDirectNotificationSending {}

@MainActor
final class DirectMiBandTransport: BandTransport {
    private let scheduler: LocalNotificationScheduling
    private let directSender: MiBandDirectNotificationSending
    private let formatter: BandNotificationFormatter
    private let notificationsEnabled: @MainActor () -> Bool
    private let liveUpdatesEnabled: @MainActor () -> Bool
    private let soundEnabled: @MainActor () -> Bool
    private let speedLimitEnabled: @MainActor () -> Bool
    private let displayStyle: @MainActor () -> BandDisplayStyle
    private var deduplicator = BandInstructionDeduplicator()
    private var isStarted = false
    private var lastLiveUpdateTimestamp: Date?
    private var lastLiveStepIdentifier: String?
    private var lastLiveDistanceMeters: Int?
    private var lastDirectSignature: DirectSignature?

    private struct DirectSignature: Equatable {
        let stepIdentifier: String
        let maneuver: NavigationManeuver
        let distanceMeters: Int
    }

    init(
        scheduler: LocalNotificationScheduling,
        directSender: MiBandDirectNotificationSending,
        formatter: BandNotificationFormatter = BandNotificationFormatter(),
        notificationsEnabled: @escaping @MainActor () -> Bool = { true },
        liveUpdatesEnabled: @escaping @MainActor () -> Bool = { false },
        soundEnabled: @escaping @MainActor () -> Bool = { false },
        speedLimitEnabled: @escaping @MainActor () -> Bool = { true },
        displayStyle: @escaping @MainActor () -> BandDisplayStyle = { .compact }
    ) {
        self.scheduler = scheduler
        self.directSender = directSender
        self.formatter = formatter
        self.notificationsEnabled = notificationsEnabled
        self.liveUpdatesEnabled = liveUpdatesEnabled
        self.soundEnabled = soundEnabled
        self.speedLimitEnabled = speedLimitEnabled
        self.displayStyle = displayStyle
    }

    func start() async throws {
        isStarted = true
        deduplicator.reset()
        resetLiveUpdates()
    }

    func stop() {
        isStarted = false
        deduplicator.reset()
        resetLiveUpdates()
        directSender.stopFullscreenNavigation()
    }

    func send(_ instruction: NavigationInstruction) async throws {
        guard isStarted else { throw BandTransportError.notStarted }
        guard notificationsEnabled(), deduplicator.shouldSend(instruction) else { return }

        let content = formatter.format(
            instruction,
            soundEnabled: soundEnabled(),
            includeSpeedLimit: speedLimitEnabled(),
            displayStyle: displayStyle()
        )
        let directAvailable = directSender.canSendDirectNotifications
        let signature = directSignature(for: instruction)
        if directAvailable, signature != lastDirectSignature {
            directSender.sendNavigationInstruction(
                instruction,
                title: content.title,
                body: content.body,
                label: "bước \(instruction.stepIdentifier)"
            )
            lastDirectSignature = signature
        }

        do {
            try await scheduler.schedule(content)
        } catch {
            // Direct BLE delivery must not depend on iOS notification permission.
            // Preserve the previous error behavior only when the Band channel is unavailable.
            if !directAvailable { throw error }
        }
    }

    func updateLive(_ instruction: NavigationInstruction) async throws {
        guard isStarted else { throw BandTransportError.notStarted }
        guard notificationsEnabled(),
              liveUpdatesEnabled(),
              directSender.canSendDirectNotifications,
              instruction.safetyAlert == nil,
              instruction.maneuver != .destination else { return }

        let distanceMeters = Int(instruction.distanceToManeuverMeters.rounded())
        let isNewStep = lastLiveStepIdentifier != instruction.stepIdentifier
        let distanceChangedEnough = lastLiveDistanceMeters.map {
            abs($0 - distanceMeters) >= 2
        } ?? true
        let intervalElapsed = lastLiveUpdateTimestamp.map {
            instruction.timestamp.timeIntervalSince($0) >= 2
        } ?? true
        guard isNewStep || (intervalElapsed && distanceChangedEnough) else { return }

        let signature = directSignature(for: instruction)
        guard signature != lastDirectSignature else { return }
        let content = formatter.format(
            instruction,
            soundEnabled: false,
            includeSpeedLimit: speedLimitEnabled(),
            displayStyle: displayStyle()
        )
        directSender.sendNavigationInstruction(
            instruction,
            title: content.title,
            body: content.body,
            label: "realtime \(instruction.stepIdentifier)"
        )
        lastLiveUpdateTimestamp = instruction.timestamp
        lastLiveStepIdentifier = instruction.stepIdentifier
        lastLiveDistanceMeters = distanceMeters
        lastDirectSignature = signature
    }

    private func directSignature(for instruction: NavigationInstruction) -> DirectSignature {
        DirectSignature(
            stepIdentifier: instruction.stepIdentifier,
            maneuver: instruction.maneuver,
            distanceMeters: Int(instruction.distanceToManeuverMeters.rounded())
        )
    }

    private func resetLiveUpdates() {
        lastLiveUpdateTimestamp = nil
        lastLiveStepIdentifier = nil
        lastLiveDistanceMeters = nil
        lastDirectSignature = nil
    }
}
