import Combine
import Foundation

@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published private(set) var state: NavigationState = .idle
    @Published private(set) var currentInstruction: NavigationInstruction?
    @Published private(set) var lastBandNotification: NavigationInstruction?
    @Published private(set) var firedThresholds: Set<Int> = []
    @Published private(set) var configuredThresholds: [Int]
    @Published private(set) var lastError: String?

    let provider: NavigationProvider
    private let bandTransport: BandTransport
    private var notificationPolicy: BandNotificationPolicy
    private var stateTask: Task<Void, Never>?
    private var instructionTask: Task<Void, Never>?
    private var isInitialized = false
    private let notificationThresholdProvider: (@MainActor () -> [Int])?

    init(
        provider: NavigationProvider,
        bandTransport: BandTransport,
        notificationPolicy: BandNotificationPolicy = BandNotificationPolicy(),
        notificationThresholdProvider: (@MainActor () -> [Int])? = nil
    ) {
        self.provider = provider
        self.bandTransport = bandTransport
        self.notificationPolicy = notificationPolicy
        configuredThresholds = notificationPolicy.thresholds
        self.notificationThresholdProvider = notificationThresholdProvider
        connectStreams()
    }

    func initialize() async {
        guard !isInitialized else { return }
        do {
            try await bandTransport.start()
            try await provider.initialize()
            isInitialized = true
            lastError = nil
        } catch {
            report(error)
        }
    }

    func calculateRoute(to destination: Destination, travelMode: TravelMode) async {
        await initialize()
        do {
            if let notificationThresholdProvider {
                notificationPolicy = BandNotificationPolicy(
                    thresholds: notificationThresholdProvider(),
                    cooldownSeconds: notificationPolicy.cooldownSeconds
                )
                configuredThresholds = notificationPolicy.thresholds
            }
            notificationPolicy.reset()
            firedThresholds = []
            try await provider.calculateRoute(to: destination, travelMode: travelMode)
            lastError = nil
        } catch {
            report(error)
        }
    }

    func startNavigation() async {
        do {
            try await provider.startNavigation()
            lastError = nil
        } catch {
            report(error)
        }
    }

    func startMockRoute() async {
        let destination = Destination(
            displayName: "Điểm đến mô phỏng",
            formattedAddress: "Hà Nội, Việt Nam",
            latitude: 21.0285,
            longitude: 105.8542
        )
        await calculateRoute(to: destination, travelMode: .motorcycle)
        guard lastError == nil else { return }
        await startNavigation()
    }

    func stopNavigation() {
        provider.stopNavigation()
        bandTransport.stop()
        isInitialized = false
        notificationPolicy.reset()
        firedThresholds = []
    }

    private func connectStreams() {
        stateTask?.cancel()
        instructionTask?.cancel()

        let states = provider.stateStream()
        stateTask = Task { [weak self] in
            for await state in states {
                guard !Task.isCancelled else { return }
                self?.state = state
                AppLogger.navigation.info("Navigation state changed: \(String(describing: state), privacy: .public)")
            }
        }

        let instructions = provider.instructionStream()
        instructionTask = Task { [weak self] in
            for await instruction in instructions {
                guard !Task.isCancelled else { return }
                await self?.process(instruction)
            }
        }
    }

    private func process(_ instruction: NavigationInstruction) async {
        currentInstruction = instruction
        let decision = notificationPolicy.evaluate(instruction)
        firedThresholds = notificationPolicy.firedThresholds
        guard let notification = decision.notification else { return }

        do {
            try await bandTransport.send(notification)
            lastBandNotification = notification
            lastError = nil
            AppLogger.band.info("Wearable notification delivered for a policy-approved threshold")
        } catch {
            report(error, updateNavigationState: false)
        }
    }

    private func report(_ error: Error, updateNavigationState: Bool = true) {
        lastError = error.localizedDescription
        AppLogger.error.error("Navigation pipeline error: \(error.localizedDescription, privacy: .private)")
        if updateNavigationState {
            state = .error(error.localizedDescription)
        }
    }
}
