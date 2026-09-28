import Foundation

@MainActor
final class NotificationBandTransport: BandTransport {
    private let scheduler: LocalNotificationScheduling
    private let formatter: BandNotificationFormatter
    private let notificationsEnabled: @MainActor () -> Bool
    private let soundEnabled: @MainActor () -> Bool
    private let speedLimitEnabled: @MainActor () -> Bool
    private var deduplicator = BandInstructionDeduplicator()
    private var isStarted = false

    init(
        scheduler: LocalNotificationScheduling,
        formatter: BandNotificationFormatter = BandNotificationFormatter(),
        notificationsEnabled: @escaping @MainActor () -> Bool = { true },
        soundEnabled: @escaping @MainActor () -> Bool = { false },
        speedLimitEnabled: @escaping @MainActor () -> Bool = { true }
    ) {
        self.scheduler = scheduler
        self.formatter = formatter
        self.notificationsEnabled = notificationsEnabled
        self.soundEnabled = soundEnabled
        self.speedLimitEnabled = speedLimitEnabled
    }

    func start() async throws {
        isStarted = true
        deduplicator.reset()
    }

    func stop() {
        isStarted = false
        deduplicator.reset()
    }

    func send(_ instruction: NavigationInstruction) async throws {
        guard isStarted else { throw BandTransportError.notStarted }
        guard notificationsEnabled(), deduplicator.shouldSend(instruction) else { return }
        try await scheduler.schedule(
            formatter.format(
                instruction,
                soundEnabled: soundEnabled(),
                includeSpeedLimit: speedLimitEnabled()
            )
        )
    }
}
