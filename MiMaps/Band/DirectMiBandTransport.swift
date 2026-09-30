import Foundation

@MainActor
protocol MiBandDirectNotificationSending: AnyObject {
    var canSendDirectNotifications: Bool { get }
    func sendDirectNotification(title: String, body: String, label: String)
}

extension MiBandDirectConnection: MiBandDirectNotificationSending {}

@MainActor
final class DirectMiBandTransport: BandTransport {
    private let scheduler: LocalNotificationScheduling
    private let directSender: MiBandDirectNotificationSending
    private let formatter: BandNotificationFormatter
    private let notificationsEnabled: @MainActor () -> Bool
    private let soundEnabled: @MainActor () -> Bool
    private let speedLimitEnabled: @MainActor () -> Bool
    private let displayStyle: @MainActor () -> BandDisplayStyle
    private var deduplicator = BandInstructionDeduplicator()
    private var isStarted = false

    init(
        scheduler: LocalNotificationScheduling,
        directSender: MiBandDirectNotificationSending,
        formatter: BandNotificationFormatter = BandNotificationFormatter(),
        notificationsEnabled: @escaping @MainActor () -> Bool = { true },
        soundEnabled: @escaping @MainActor () -> Bool = { false },
        speedLimitEnabled: @escaping @MainActor () -> Bool = { true },
        displayStyle: @escaping @MainActor () -> BandDisplayStyle = { .compact }
    ) {
        self.scheduler = scheduler
        self.directSender = directSender
        self.formatter = formatter
        self.notificationsEnabled = notificationsEnabled
        self.soundEnabled = soundEnabled
        self.speedLimitEnabled = speedLimitEnabled
        self.displayStyle = displayStyle
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

        let content = formatter.format(
            instruction,
            soundEnabled: soundEnabled(),
            includeSpeedLimit: speedLimitEnabled(),
            displayStyle: displayStyle()
        )
        let directAvailable = directSender.canSendDirectNotifications
        if directAvailable {
            directSender.sendDirectNotification(
                title: content.title,
                body: content.body,
                label: "bước \(instruction.stepIdentifier)"
            )
        }

        do {
            try await scheduler.schedule(content)
        } catch {
            // Direct BLE delivery must not depend on iOS notification permission.
            // Preserve the previous error behavior only when the Band channel is unavailable.
            if !directAvailable { throw error }
        }
    }
}
