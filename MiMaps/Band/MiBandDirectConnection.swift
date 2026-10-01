@preconcurrency import CoreBluetooth
import Foundation
import Security

@MainActor
final class MiBandDirectConnection: NSObject, ObservableObject {
    @Published private(set) var state: MiBandConnectionState = .idle
    @Published private(set) var discoveredDevices: [MiBandDevice] = []
    @Published private(set) var characteristics: [MiBandGATTCharacteristic] = []
    @Published private(set) var eventLog: [String] = []
    @Published private(set) var capturedPackets: [MiBandCapturedPacket] = []
    @Published private(set) var isCapturingPackets = false
    @Published private(set) var savedKeyFingerprint: String?
    @Published private(set) var authenticationState: MiBandAuthenticationState = .missingKey
    @Published private(set) var directNotificationState: MiBandDirectNotificationState = .unavailable
    @Published private(set) var decryptedPacketCount = 0
    @Published private(set) var sentCommandCount = 0
    @Published private(set) var lastDecryptedCommandPreview: String?
    @Published private(set) var lastIconRequestDescription: String?
    @Published private(set) var iconUploadDescription: String = "chưa bắt đầu"
    @Published private(set) var pictureModeDescription: String = "chưa bắt đầu"
    @Published private(set) var firmwareVersion: String?
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var watchfaces: [MiBandWatchfaceProtocol.WatchfaceInfo] = []
    @Published private(set) var previousWatchfaceIdentifier: String?
    @Published private(set) var watchfaceInstallationState: MiBandWatchfaceInstallationState = .unavailable
    @Published private(set) var fullscreenNavigationEnabled = false
    @Published private(set) var watchfaceUploadDescription = "chưa bắt đầu"

    private enum StorageKey {
        static let peripheralIdentifier = "directMiBandPeripheralIdentifier"
        static let previousWatchfaceIdentifier = "directMiBandPreviousWatchfaceIdentifier"
        static let watchfaceIdentifierCounter = "directMiBandWatchfaceIdentifierCounter"
        static let generatedWatchfaceIdentifiers = "directMiBandGeneratedWatchfaceIdentifiers"
    }

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var pendingServiceUUIDs: Set<CBUUID> = []
    private var characteristicHandles: [String: CBCharacteristic] = [:]
    private var authenticationAttemptID: UUID?
    private var authenticationContext: AuthenticationContext?
    private var authenticationNotificationStage: AuthenticationNotificationStage = .idle
    private var lastConnectedDeviceName: String?
    private var lastConnectedDeviceIdentifier: UUID?
    private var outgoingEncryptionCounter: UInt16 = 1
    private var nextNotificationIdentifier: UInt32
    private var activeNavigationNotificationIdentifier: UInt32?
    private var activeNavigationPackage: String?
    private var queuedCommands: [QueuedCommand] = []
    private var pendingCommand: QueuedCommand?
    private var pendingPictureNotification: PendingPictureNotification?
    private var pictureModeAttemptID: UUID?
    private var lastNavigationManeuver: NavigationManeuver?
    private var uploadedIconManeuver: NavigationManeuver?
    private var dataUploadManeuver: NavigationManeuver?
    private var lastIconPackageName: String?
    private var pendingUploadBytes: Data?
    private var dataUploadPurpose: DataUploadPurpose?
    private var dataUploadParts: [Data] = []
    private var nextDataUploadPartIndex = 0
    private var auxiliaryFrames: [Data] = []
    private var pendingAuxiliaryFrameIndexes: [Int] = []
    private var pendingDataUploadControlFrame: Data?
    private var dataUploadAttemptID: UUID?
    private var dataUploadPhase: DataUploadPhase = .idle
    private var preparedWatchfacePackage: MiBandWatchfacePackage?
    private var activeMiMapsWatchfaceIdentifier: String?
    private var pendingRealtimeInstruction: NavigationInstruction?
    private var lastFullscreenInstruction: NavigationInstruction?
    private var lastFullscreenUpdateTimestamp: Date?
    private var fullscreenRiskAcknowledgedForSession = false
    private var restoreRequestedAfterTransfer = false
    private let watchfaceRealtimePolicy = MiBandWatchfaceRealtimePolicy()
    private let defaults: UserDefaults
    private let now: () -> Date
    private let credentialStore: MiBandCredentialStoring
    private let notificationIconCache: MiBandNotificationIconCache

    private struct AuthenticationContext {
        let secretKey: Data
        let phoneNonce: Data
        var sessionKeys: MiBandSessionKeys?
    }

    private struct QueuedCommand: Equatable {
        let id: UUID
        let label: String
        let command: Data
    }

    private struct PendingPictureNotification: Equatable {
        let id: UUID
        let label: String
        let command: Data
        let maneuver: NavigationManeuver
        let package: String
    }

    private enum PictureModeFallback {
        static let bootstrapLabel = "mở picture mode"
    }

    private enum ProtocolCharacteristic {
        static let commandRead = "FE95/0051"
        static let commandWrite = "FE95/0052"
        static let dataUpload = "FE95/0055"
    }

    private enum DataUploadTransport {
        // The Band 8 channel follows Xiaomi's 244-byte BLE frame limit. A
        // larger CoreBluetooth write-with-response becomes an ATT long write,
        // which FE95/0055 rejects with "The attribute is not long".
        static let maximumFrameLength = 244
    }

    private enum DataUploadPurpose: Equatable {
        case notificationIcon(NavigationManeuver?)
        case watchface(identifier: String)

        var type: UInt8 {
            switch self {
            case .notificationIcon: MiBandDataUploadProtocol.notificationIconType
            case .watchface: MiBandWatchfaceProtocol.uploadType
            }
        }

        var noun: String {
            switch self {
            case .notificationIcon: "icon"
            case .watchface: "mặt đồng hồ"
            }
        }
    }

    private enum DataUploadPhase: String {
        case idle
        case enablingNotifications
        case waitingRequestAcknowledgement
        case writingSingleFrame
        case waitingSingleAcknowledgement
        case writingChunkStart
        case waitingChunkStartAcknowledgement
        case writingChunks
        case waitingChunkEndAcknowledgement
    }

    private enum AuthenticationNotificationStage: String, Equatable {
        case idle
        case enablingWrite = "bật notify FE95/0052"
        case enablingRead = "bật notify FE95/0051"
        case ready = "gửi nonce"
    }

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        credentialStore: MiBandCredentialStoring = MiBandCredentialStore()
    ) {
        self.defaults = defaults
        self.now = now
        self.credentialStore = credentialStore
        self.notificationIconCache = MiBandNotificationIconCache(defaults: defaults)
        self.previousWatchfaceIdentifier = defaults.string(
            forKey: StorageKey.previousWatchfaceIdentifier
        )
        self.nextNotificationIdentifier = MiBandNotificationProtocol
            .sessionNotificationIdentifier(at: now())
        super.init()
        refreshSavedKeyState()
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    var connectedDeviceName: String? {
        connectedPeripheral?.name
    }

    var hasSavedDevice: Bool {
        defaults.string(forKey: StorageKey.peripheralIdentifier) != nil
    }

    var canSendDirectNotifications: Bool {
        state.isReady
            && authenticationState == .authenticated
            && authenticationContext?.sessionKeys != nil
    }

    func startScan() {
        guard central.state == .poweredOn else {
            state = .bluetoothUnavailable(Self.bluetoothDescription(central.state))
            appendEvent("Không thể quét: \(Self.bluetoothDescription(central.state))")
            return
        }

        discoveredDevices = []
        peripherals = [:]
        state = .scanning
        appendEvent("Bắt đầu quét thiết bị Bluetooth lân cận")
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func stopScan() {
        central.stopScan()
        if state == .scanning { state = .idle }
        appendEvent("Dừng quét")
    }

    func connect(to device: MiBandDevice) {
        guard let peripheral = peripherals[device.id] else {
            state = .failed("Thiết bị không còn trong phạm vi quét.")
            return
        }

        central.stopScan()
        characteristics = []
        characteristicHandles = [:]
        pendingServiceUUIDs = []
        state = .connecting(device.name)
        appendEvent("Yêu cầu kết nối \(device.name) [\(device.id.uuidString)]")
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let connectedPeripheral else {
            state = .disconnected
            return
        }
        appendEvent("Yêu cầu ngắt kết nối \(connectedPeripheral.name ?? "Mi Band")")
        central.cancelPeripheralConnection(connectedPeripheral)
    }

    func saveAuthenticationKey(_ value: String) throws {
        try credentialStore.save(authenticationKey: value)
        refreshSavedKeyState()
        appendEvent("Đã lưu khóa xác thực an toàn trong Keychain")
    }

    func deleteAuthenticationKey() throws {
        try credentialStore.deleteAuthenticationKey()
        refreshSavedKeyState()
        appendEvent("Đã xóa khóa xác thực khỏi Keychain")
    }

    func startPacketCapture() {
        guard let peripheral = connectedPeripheral, state.isReady else {
            appendEvent("Không thể thu dữ liệu: thiết bị chưa sẵn sàng")
            return
        }

        capturedPackets = []
        isCapturingPackets = true
        let candidates = characteristicHandles.values.filter(Self.isProtocolNotifyCandidate)
        for characteristic in candidates {
            peripheral.setNotifyValue(true, for: characteristic)
        }
        appendEvent("Bắt đầu thu dữ liệu thụ động trên \(candidates.count) characteristic")
    }

    func stopPacketCapture() {
        isCapturingPackets = false
        appendEvent("Dừng thu dữ liệu thụ động")
    }

    func authenticate() {
        appendEvent("Người dùng yêu cầu xác thực trực tiếp")
        guard state.isReady, let peripheral = connectedPeripheral else {
            failAuthentication("Thiết bị chưa sẵn sàng.")
            return
        }
        guard let storedKey = credentialStore.loadAuthenticationKey() else {
            authenticationState = .missingKey
            appendEvent("Không thể xác thực: chưa có khóa trong Keychain")
            return
        }
        guard characteristicHandles[ProtocolCharacteristic.commandRead] != nil,
              let commandWrite = characteristicHandles[ProtocolCharacteristic.commandWrite] else {
            failAuthentication("Không tìm thấy kênh FE95/0051–0052.")
            return
        }

        do {
            let secretKey = try MiBandAuthProtocol.keyData(from: storedKey)
            var nonce = Data(count: 16)
            let status = nonce.withUnsafeMutableBytes { buffer in
                SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
            }
            guard status == errSecSuccess else {
                failAuthentication("Không tạo được dữ liệu ngẫu nhiên an toàn.")
                return
            }

            let attemptID = UUID()
            authenticationAttemptID = attemptID
            authenticationContext = AuthenticationContext(
                secretKey: secretKey,
                phoneNonce: nonce,
                sessionKeys: nil
            )
            authenticationState = .subscribing
            authenticationNotificationStage = .enablingWrite
            appendEvent("Bước 1/3: bật notify FE95/0052")
            if commandWrite.isNotifying {
                advanceAuthenticationSubscriptions(
                    notifiedKey: ProtocolCharacteristic.commandWrite,
                    peripheral: peripheral
                )
            } else {
                peripheral.setNotifyValue(true, for: commandWrite)
            }
            scheduleAuthenticationTimeout(for: attemptID)
        } catch {
            failAuthentication(error.localizedDescription)
        }
    }

    func sendTestNavigationNotification() {
        sendDirectNotification(
            title: "← 100 m",
            body: "Rẽ trái · MiMaps",
            label: "thông báo thử",
            maneuver: .left
        )
    }

    func refreshWatchfaceState() {
        guard canSendDirectNotifications else {
            watchfaceInstallationState = .failed(
                MiBandWatchfaceSafetyError.notConnected.localizedDescription
            )
            return
        }
        requestDeviceInformation()
        watchfaceInstallationState = .awaitingDeviceInfo
        enqueueCommand(
            MiBandWatchfaceProtocol.makeListCommand(),
            label: "đọc danh sách mặt đồng hồ"
        )
    }

    @discardableResult
    func prepareFullscreenPackage(_ instruction: NavigationInstruction) -> MiBandWatchfacePackage? {
        do {
            let package = try MiBandNavigationCardRenderer.watchfacePackage(
                instruction,
                identifier: takeNextWatchfaceIdentifier()
            )
            preparedWatchfacePackage = package
            watchfaceInstallationState = .packageReady(
                identifier: package.identifier,
                byteCount: package.bytes.count
            )
            watchfaceUploadDescription = "đã kiểm tra \(package.bytes.count) byte"
            appendEvent(
                "Đã tạo gói điều hướng toàn màn hình \(package.identifier), "
                    + "\(package.bytes.count) byte"
            )
            return package
        } catch {
            watchfaceInstallationState = .failed(error.localizedDescription)
            watchfaceUploadDescription = "lỗi tạo gói: \(error.localizedDescription)"
            appendEvent("Không thể tạo gói toàn màn hình: \(error.localizedDescription)")
            return nil
        }
    }

    func installPreparedFullscreenWatchface(riskAcknowledged: Bool) {
        do {
            try MiBandWatchfaceSafetySnapshot(
                isConnectedAndAuthenticated: canSendDirectNotifications,
                firmwareVersion: firmwareVersion,
                batteryLevel: batteryLevel,
                previousWatchfaceIdentifier: previousWatchfaceIdentifier,
                hasValidatedPackage: preparedWatchfacePackage != nil,
                riskAcknowledged: riskAcknowledged
            ).validate()
            guard let package = preparedWatchfacePackage else {
                throw MiBandWatchfaceSafetyError.packageMissing
            }
            fullscreenRiskAcknowledgedForSession = true
            startWatchfaceInstallation(package)
        } catch {
            watchfaceInstallationState = .failed(error.localizedDescription)
            appendEvent("Chặn cài mặt đồng hồ: \(error.localizedDescription)")
        }
    }

    func restorePreviousWatchface() {
        guard canSendDirectNotifications else {
            watchfaceInstallationState = .failed(
                MiBandWatchfaceSafetyError.notConnected.localizedDescription
            )
            return
        }
        guard let identifier = previousWatchfaceIdentifier else {
            watchfaceInstallationState = .failed(
                MiBandWatchfaceSafetyError.activeWatchfaceUnknown.localizedDescription
            )
            return
        }
        fullscreenNavigationEnabled = false
        pendingRealtimeInstruction = nil
        if dataUploadPhase != .idle || isWatchfaceTransitionInProgress {
            restoreRequestedAfterTransfer = true
            appendEvent("Đã xếp yêu cầu khôi phục sau khi phiên hiện tại kết thúc")
            return
        }
        watchfaceInstallationState = .restoring(identifier: identifier)
        appendEvent("Khôi phục mặt đồng hồ trước đó \(identifier)")
        enqueueCommand(
            MiBandWatchfaceProtocol.makeSetCommand(identifier: identifier),
            label: "khôi phục mặt đồng hồ \(identifier)"
        )
    }

    func sendNavigationInstruction(
        _ instruction: NavigationInstruction,
        title: String,
        body: String,
        label: String
    ) {
        guard fullscreenNavigationEnabled else {
            sendDirectNotification(
                title: title,
                body: body,
                label: label,
                maneuver: instruction.maneuver
            )
            return
        }
        queueFullscreenNavigationUpdate(instruction)
    }

    func stopFullscreenNavigation() {
        guard fullscreenNavigationEnabled else { return }
        restorePreviousWatchface()
    }

    func sendDirectNotification(
        title: String,
        body: String,
        label: String = "chỉ dẫn điều hướng",
        maneuver: NavigationManeuver? = nil
    ) {
        guard canSendDirectNotifications else {
            directNotificationState = .failed("Hãy kết nối và xác thực Band trước khi gửi.")
            appendEvent("Không thể gửi trực tiếp: phiên bảo mật chưa sẵn sàng")
            return
        }
        let package = MiBandManeuverIconRenderer.packageName(for: maneuver)
        let iconIsCached = maneuver != nil && notificationIconCache.contains(
            package: package,
            deviceIdentifier: connectedPeripheral?.identifier
        )
        let notificationID: UInt32
        if maneuver == nil {
            notificationID = takeNextNotificationIdentifier()
        } else if activeNavigationPackage == package,
                  let activeNavigationNotificationIdentifier {
            notificationID = activeNavigationNotificationIdentifier
        } else {
            notificationID = takeNextNotificationIdentifier()
            activeNavigationNotificationIdentifier = notificationID
            activeNavigationPackage = package
            uploadedIconManeuver = nil
            appendEvent(
                "Picture mode: dùng notification ID mới \(notificationID) cho \(package)"
            )
        }
        if iconIsCached, let maneuver {
            uploadedIconManeuver = maneuver
            pictureModeDescription = "Band dùng icon đã cache; gửi realtime"
            iconUploadDescription = "đã có trong cache của Band"
        }
        let command = MiBandNotificationProtocol.makeNotificationCommand(
            id: notificationID,
            title: title,
            body: body,
            date: now(),
            packageName: package
        )
        lastNavigationManeuver = maneuver
        if let maneuver, maneuver != uploadedIconManeuver {
            beginPictureModeDelivery(
                command: command,
                label: label,
                package: package,
                maneuver: maneuver
            )
        } else {
            enqueueCommand(command, label: label)
        }
    }

    private func takeNextNotificationIdentifier() -> UInt32 {
        let identifier = nextNotificationIdentifier
        nextNotificationIdentifier = MiBandNotificationProtocol
            .incrementedNotificationIdentifier(after: identifier)
        return identifier
    }

    private func takeNextWatchfaceIdentifier() -> String {
        let previous = defaults.integer(forKey: StorageKey.watchfaceIdentifierCounter)
        let next = previous >= 999_999 ? 1 : previous + 1
        defaults.set(next, forKey: StorageKey.watchfaceIdentifierCounter)
        return String(format: "298%06d", next)
    }

    private func startWatchfaceInstallation(_ package: MiBandWatchfacePackage) {
        guard dataUploadPhase == .idle else {
            watchfaceInstallationState = .failed("Một phiên upload khác đang chạy.")
            return
        }
        preparedWatchfacePackage = package
        rememberGeneratedWatchfaceIdentifier(package.identifier)
        watchfaceInstallationState = .requestingInstall(identifier: package.identifier)
        watchfaceUploadDescription = "đang yêu cầu cài \(package.identifier)"
        appendEvent(
            "Mở phiên cài mặt đồng hồ \(package.identifier), \(package.bytes.count) byte"
        )
        enqueueCommand(
            MiBandWatchfaceProtocol.makeInstallStartCommand(
                identifier: package.identifier,
                byteCount: package.bytes.count
            ),
            label: "mở phiên cài \(package.identifier)"
        )
    }

    private func queueFullscreenNavigationUpdate(_ instruction: NavigationInstruction) {
        guard fullscreenRiskAcknowledgedForSession else {
            fullscreenNavigationEnabled = false
            watchfaceInstallationState = .failed("Phiên này chưa xác nhận rủi ro.")
            return
        }
        guard watchfaceRealtimePolicy.shouldBuild(
            previousTimestamp: lastFullscreenUpdateTimestamp,
            previousInstruction: lastFullscreenInstruction,
            next: instruction
        ) else { return }

        if dataUploadPhase != .idle
            || pendingCommand != nil
            || !queuedCommands.isEmpty
            || isWatchfaceTransitionInProgress {
            pendingRealtimeInstruction = instruction
            appendEvent("Đã gộp cập nhật toàn màn hình; giữ chỉ dẫn mới nhất")
            return
        }
        guard let package = prepareFullscreenPackage(instruction) else { return }
        lastFullscreenInstruction = instruction
        lastFullscreenUpdateTimestamp = instruction.timestamp
        startWatchfaceInstallation(package)
    }

    private var isWatchfaceTransitionInProgress: Bool {
        switch watchfaceInstallationState {
        case .requestingInstall, .uploading, .activating, .restoring:
            true
        default:
            false
        }
    }

    private func rememberGeneratedWatchfaceIdentifier(_ identifier: String) {
        var identifiers = Set(
            defaults.stringArray(forKey: StorageKey.generatedWatchfaceIdentifiers) ?? []
        )
        identifiers.insert(identifier)
        defaults.set(Array(identifiers).sorted(), forKey: StorageKey.generatedWatchfaceIdentifiers)
    }

    private func isGeneratedWatchfaceIdentifier(_ identifier: String) -> Bool {
        Set(defaults.stringArray(forKey: StorageKey.generatedWatchfaceIdentifiers) ?? [])
            .contains(identifier)
    }

    func forgetDevice() {
        disconnect()
        defaults.removeObject(forKey: StorageKey.peripheralIdentifier)
        connectedPeripheral = nil
        characteristics = []
        characteristicHandles = [:]
        capturedPackets = []
        isCapturingPackets = false
        resetSecureSession()
        state = .idle
        appendEvent("Đã quên thiết bị")
    }

    func reconnectSavedDevice() {
        guard central.state == .poweredOn,
              let value = defaults.string(forKey: StorageKey.peripheralIdentifier),
              let identifier = UUID(uuidString: value) else {
            return
        }

        guard let peripheral = central.retrievePeripherals(withIdentifiers: [identifier]).first else {
            appendEvent("Không tìm thấy thiết bị đã lưu; cần quét lại")
            return
        }

        let name = peripheral.name ?? "Mi Band 8"
        peripherals[identifier] = peripheral
        state = .connecting(name)
        appendEvent("Kết nối lại \(name)")
        central.connect(peripheral, options: nil)
    }

    func diagnosticsReport() -> String {
        let device = connectedPeripheral
        let header = [
            "MiMaps Band Lab",
            "Generated: \(ISO8601DateFormatter().string(from: now()))",
            "Bluetooth: \(Self.bluetoothDescription(central.state))",
            "State: \(state.localizedDescription)",
            "Device: \(device?.name ?? lastConnectedDeviceName ?? "—")",
            "Identifier: \(device?.identifier.uuidString ?? lastConnectedDeviceIdentifier?.uuidString ?? "—")",
            "GATT characteristics: \(characteristics.count)",
            "Authentication key: \(savedKeyFingerprint == nil ? "not configured" : "configured")",
            "Authentication: \(authenticationState.localizedDescription)",
            "Authentication phase: \(authenticationNotificationStage.rawValue)",
            "Direct notification: \(directNotificationState.localizedDescription)",
            "Picture mode: \(pictureModeDescription)",
            "Decrypted session packets: \(decryptedPacketCount)",
            "Last decrypted command: \(lastDecryptedCommandPreview ?? "—")",
            "Last icon request: \(lastIconRequestDescription ?? "—")",
            "Icon upload: \(iconUploadDescription)",
            "Firmware: \(firmwareVersion ?? "—")",
            "Battery: \(batteryLevel.map { "\($0)%" } ?? "—")",
            "Previous watchface: \(previousWatchfaceIdentifier ?? "—")",
            "Fullscreen navigation: \(fullscreenNavigationEnabled ? "enabled" : "disabled")",
            "Watchface state: \(watchfaceInstallationState.localizedDescription)",
            "Watchface upload: \(watchfaceUploadDescription)",
            "Encrypted commands sent: \(sentCommandCount)",
            "Captured packets: \(capturedPackets.count)",
            ""
        ]

        let gatt = characteristics.map { item in
            "\(item.serviceUUID) / \(item.characteristicUUID) [\(item.properties.joined(separator: ", "))]"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        let packets = capturedPackets.map {
            "[\(formatter.string(from: $0.timestamp))] \($0.serviceUUID) / \($0.characteristicUUID) len=\($0.byteCount) \($0.hexPreview)"
        }
        let events = ["", "Packets:"] + packets + ["", "Events:"] + eventLog
        return (header + gatt + events).joined(separator: "\n")
    }

    private func appendEvent(_ message: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        eventLog.append("[\(formatter.string(from: now()))] \(message)")
        if eventLog.count > 150 {
            eventLog.removeFirst(eventLog.count - 150)
        }
    }

    private func finishDiscoveryIfPossible() {
        guard pendingServiceUUIDs.isEmpty, let peripheral = connectedPeripheral else { return }
        characteristics.sort {
            ($0.serviceUUID, $0.characteristicUUID) < ($1.serviceUUID, $1.characteristicUUID)
        }
        let name = peripheral.name ?? "Mi Band 8"
        state = .ready(name)
        defaults.set(peripheral.identifier.uuidString, forKey: StorageKey.peripheralIdentifier)
        appendEvent("Khám phá GATT hoàn tất: \(characteristics.count) characteristic")
        requestDeviceInformation()
    }

    private func requestDeviceInformation() {
        guard let peripheral = connectedPeripheral else { return }
        for key in ["180A/2A26", "180F/2A19"] {
            guard let characteristic = characteristicHandles[key],
                  characteristic.properties.contains(.read) else { continue }
            peripheral.readValue(for: characteristic)
        }
    }

    private func refreshSavedKeyState() {
        savedKeyFingerprint = credentialStore.loadAuthenticationKey().map(MiBandAuthenticationKey.fingerprint)
        guard !authenticationState.isInProgress, authenticationState != .authenticated else { return }
        authenticationState = savedKeyFingerprint == nil ? .missingKey : .ready
    }

    private func advanceAuthenticationSubscriptions(notifiedKey: String, peripheral: CBPeripheral) {
        guard authenticationState == .subscribing else { return }
        switch (authenticationNotificationStage, notifiedKey) {
        case (.enablingWrite, let key) where key == ProtocolCharacteristic.commandWrite:
            guard let read = characteristicHandles[ProtocolCharacteristic.commandRead] else {
                failAuthentication("Không tìm thấy FE95/0051.")
                return
            }
            authenticationNotificationStage = .enablingRead
            appendEvent("Bước 2/3: notify FE95/0052 đã bật; tiếp tục FE95/0051")
            if read.isNotifying {
                advanceAuthenticationSubscriptions(
                    notifiedKey: ProtocolCharacteristic.commandRead,
                    peripheral: peripheral
                )
            } else {
                peripheral.setNotifyValue(true, for: read)
            }
        case (.enablingRead, let key) where key == ProtocolCharacteristic.commandRead:
            authenticationNotificationStage = .ready
            appendEvent("Bước 3/3: hai kênh notify đã sẵn sàng; chuẩn bị gửi nonce")
            guard let attemptID = authenticationAttemptID else { return }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                self?.sendAuthenticationNonce(for: attemptID)
            }
        default:
            break
        }
    }

    private func sendAuthenticationNonce(for attemptID: UUID) {
        guard authenticationAttemptID == attemptID,
              authenticationState == .subscribing,
              authenticationNotificationStage == .ready,
              let peripheral = connectedPeripheral,
              let write = characteristicHandles[ProtocolCharacteristic.commandWrite],
              let context = authenticationContext else { return }
        do {
            let command = try MiBandAuthProtocol.makePhoneNonceCommand(phoneNonce: context.phoneNonce)
            authenticationState = .waitingForWatch
            appendEvent("Gửi nonce xác thực qua FE95/0052 (\(command.count + 4) byte)")
            writeValue(MiBandAuthProtocol.plaintextFrame(command), to: write, peripheral: peripheral)
        } catch {
            failAuthentication(error.localizedDescription)
        }
    }

    private func handleProtocolPacket(
        _ data: Data,
        characteristic: CBCharacteristic,
        peripheral: CBPeripheral
    ) {
        guard let service = characteristic.service?.uuid else { return }
        let characteristicKey = Self.characteristicKey(
            service: service,
            characteristic: characteristic.uuid
        )
        if characteristicKey == ProtocolCharacteristic.dataUpload {
            handleDataUploadChannelPacket(data)
            return
        }
        guard characteristicKey == ProtocolCharacteristic.commandRead
                || characteristicKey == ProtocolCharacteristic.commandWrite else { return }

        if let result = MiBandSessionProtocol.acknowledgementResult(from: data) {
            handleCommandAcknowledgement(result)
            return
        }

        if characteristicKey == ProtocolCharacteristic.commandRead,
           MiBandSessionProtocol.isEncryptedSingleFrame(data) {
            writeValue(
                MiBandSessionProtocol.acknowledgement,
                to: characteristic,
                peripheral: peripheral
            )
            handleEncryptedSessionPacket(data)
            return
        }

        guard characteristicKey == ProtocolCharacteristic.commandRead,
              let payload = MiBandAuthProtocol.plaintextPayload(from: data) else { return }

        writeValue(
            MiBandAuthProtocol.singlePacketAcknowledgement,
            to: characteristic,
            peripheral: peripheral
        )

        do {
            switch authenticationState {
            case .waitingForWatch:
                let challenge = try MiBandAuthProtocol.parseWatchChallenge(command: payload)
                guard var context = authenticationContext else {
                    throw MiBandAuthProtocolError.unexpectedResponse
                }
                let keys = try MiBandAuthProtocol.deriveSessionKeys(
                    secretKey: context.secretKey,
                    phoneNonce: context.phoneNonce,
                    watchNonce: challenge.nonce
                )
                guard MiBandAuthProtocol.verifyWatch(
                    challenge: challenge,
                    phoneNonce: context.phoneNonce,
                    sessionKeys: keys
                ) else {
                    throw MiBandAuthProtocolError.watchVerificationFailed
                }
                context.sessionKeys = keys
                authenticationContext = context
                authenticationState = .verifying
                let command = try MiBandAuthProtocol.makeAuthenticationCommand(
                    phoneNonce: context.phoneNonce,
                    watchNonce: challenge.nonce,
                    sessionKeys: keys,
                    phoneName: "iPhone MiMaps",
                    region: Locale.current.region?.identifier ?? "VN"
                )
                guard let write = characteristicHandles[ProtocolCharacteristic.commandWrite] else {
                    throw MiBandAuthProtocolError.unexpectedResponse
                }
                writeValue(MiBandAuthProtocol.plaintextFrame(command), to: write, peripheral: peripheral)
                appendEvent("Khóa khớp với vòng; đã gửi bước xác thực cuối")
            case .verifying:
                guard try MiBandAuthProtocol.isAuthenticationSuccess(command: payload) else {
                    throw MiBandAuthProtocolError.watchVerificationFailed
                }
                authenticationAttemptID = nil
                authenticationNotificationStage = .idle
                authenticationState = .authenticated
                outgoingEncryptionCounter = 1
                directNotificationState = .ready
                appendEvent("Xác thực trực tiếp Xiaomi Smart Band 8 thành công")
                refreshWatchfaceState()
            default:
                break
            }
        } catch MiBandAuthProtocolError.unexpectedResponse {
            // Một ứng dụng khác có thể đang dùng cùng kênh; bỏ qua lệnh không thuộc
            // phiên xác thực do MiMaps khởi tạo.
        } catch {
            failAuthentication(error.localizedDescription)
        }
    }

    private func handleEncryptedSessionPacket(_ data: Data) {
        guard authenticationState == .authenticated,
              let sessionKeys = authenticationContext?.sessionKeys else {
            appendEvent("Đã ACK khung mã hóa nhưng chưa có khóa phiên để giải mã")
            return
        }
        do {
            let command = try MiBandSessionProtocol.decryptIncomingSingleFrame(
                data,
                sessionKeys: sessionKeys
            )
            decryptedPacketCount += 1
            let envelope = MiBandSessionProtocol.commandEnvelope(from: command)
            let type = envelope.type.map { String($0) } ?? "?"
            let subtype = envelope.subtype.map { String($0) } ?? "?"
            lastDecryptedCommandPreview = MiBandCapturedPacket.preview(command, limit: 96)
            appendEvent("Đã ACK và giải mã gói phiên #\(decryptedPacketCount): type=\(type), subtype=\(subtype)")

            if let list = try MiBandWatchfaceProtocol.watchfaceList(from: command) {
                handleWatchfaceList(list)
            } else if let status = try MiBandWatchfaceProtocol.installStatus(from: command) {
                try handleWatchfaceInstallStatus(status)
            } else if let acknowledgement = try MiBandWatchfaceProtocol.setAcknowledgement(from: command) {
                handleWatchfaceSetAcknowledgement(acknowledgement)
            } else if let acknowledgement = try MiBandWatchfaceProtocol.deleteAcknowledgement(from: command) {
                appendEvent("Band ACK xóa mặt đồng hồ: \(acknowledgement)")
            } else if let package = try MiBandNotificationIconProtocol.packageQuery(from: command) {
                guard package.hasPrefix("com.mimaps") else {
                    appendEvent("Bỏ qua yêu cầu icon không thuộc MiMaps: \(package)")
                    return
                }
                lastIconPackageName = package
                lastIconRequestDescription = "query package=\(package)"
                pictureModeDescription = "Band đã hỏi package; trả lời icon"
                appendEvent("Band hỏi icon cho package \(package); gửi phản hồi theo giao thức")
                enqueueCommand(
                    MiBandNotificationIconProtocol.makePackageReply(package: package),
                    label: "phản hồi icon \(package)"
                )
            } else if let request = try MiBandNotificationIconProtocol.iconRequest(from: command) {
                let requestedManeuver: NavigationManeuver?
                if lastIconPackageName == pendingPictureNotification?.package {
                    requestedManeuver = pendingPictureNotification?.maneuver
                } else {
                    requestedManeuver = lastIconPackageName.flatMap {
                        MiBandManeuverIconRenderer.maneuver(forPackageName: $0)
                    } ?? lastNavigationManeuver
                }
                let maneuver = requestedManeuver.map { String(describing: $0) } ?? "unknown"
                lastIconRequestDescription = "status=\(request.status), format=\(request.pixelFormat), size=\(request.size), maneuver=\(maneuver)"
                pictureModeDescription = "Band đã yêu cầu icon; đang upload"
                appendEvent("Band yêu cầu dữ liệu icon: \(lastIconRequestDescription ?? "—")")
                try beginIconUpload(request: request, maneuver: requestedManeuver)
            } else if let acknowledgement = try MiBandDataUploadProtocol.acknowledgement(from: command) {
                try handleDataUploadAcknowledgement(acknowledgement)
            }
        } catch {
            directNotificationState = .failed(error.localizedDescription)
            if isWatchfaceTransitionInProgress {
                watchfaceInstallationState = .failed(error.localizedDescription)
                watchfaceUploadDescription = "lỗi giao thức: \(error.localizedDescription)"
            }
            appendEvent("Đã ACK nhưng không giải mã được gói phiên: \(error.localizedDescription)")
        }
    }

    private func handleWatchfaceList(_ list: [MiBandWatchfaceProtocol.WatchfaceInfo]) {
        watchfaces = list
        if let active = list.first(where: \.isActive) {
            if isGeneratedWatchfaceIdentifier(active.identifier) {
                activeMiMapsWatchfaceIdentifier = active.identifier
            } else {
                previousWatchfaceIdentifier = active.identifier
                defaults.set(active.identifier, forKey: StorageKey.previousWatchfaceIdentifier)
            }
            appendEvent(
                "Mặt đồng hồ hiện tại: \(active.identifier) (\(active.name)); "
                    + "đã lưu đích khôi phục"
            )
        } else {
            appendEvent("Danh sách mặt đồng hồ không có mục active")
        }
        if !isWatchfaceTransitionInProgress {
            if let package = preparedWatchfacePackage {
                watchfaceInstallationState = .packageReady(
                    identifier: package.identifier,
                    byteCount: package.bytes.count
                )
            } else {
                watchfaceInstallationState = .ready
            }
        }
    }

    private func handleWatchfaceInstallStatus(_ status: UInt64) throws {
        guard case let .requestingInstall(identifier) = watchfaceInstallationState,
              let package = preparedWatchfacePackage,
              package.identifier == identifier else {
            appendEvent("Bỏ qua trạng thái cài mặt đồng hồ ngoài phiên MiMaps: \(status)")
            return
        }
        guard status == 0 else {
            throw MiBandWatchfaceProtocolError.installRejected(status: status)
        }
        appendEvent("Band chấp nhận cài \(identifier); bắt đầu upload type 16")
        try beginDataUpload(
            bytes: package.bytes,
            purpose: .watchface(identifier: identifier)
        )
    }

    private func handleWatchfaceSetAcknowledgement(_ acknowledgement: UInt64) {
        guard acknowledgement <= 1 else {
            watchfaceInstallationState = .failed(
                "Band từ chối kích hoạt, ACK=\(acknowledgement)."
            )
            return
        }
        switch watchfaceInstallationState {
        case let .activating(identifier):
            let previousGenerated = activeMiMapsWatchfaceIdentifier
            activeMiMapsWatchfaceIdentifier = identifier
            fullscreenNavigationEnabled = !restoreRequestedAfterTransfer
            watchfaceInstallationState = .active(identifier: identifier)
            watchfaceUploadDescription = "đã kích hoạt \(identifier)"
            appendEvent("Đã kích hoạt mặt điều hướng toàn màn hình \(identifier)")
            if let previousGenerated,
               previousGenerated != identifier,
               isGeneratedWatchfaceIdentifier(previousGenerated) {
                enqueueCommand(
                    MiBandWatchfaceProtocol.makeDeleteCommand(identifier: previousGenerated),
                    label: "dọn mặt MiMaps cũ \(previousGenerated)"
                )
            }
            enqueueCommand(
                MiBandWatchfaceProtocol.makeListCommand(),
                label: "xác minh mặt đồng hồ đã kích hoạt"
            )
            if restoreRequestedAfterTransfer {
                restoreRequestedAfterTransfer = false
                restorePreviousWatchface()
            } else {
                processPendingRealtimeInstructionAfterTransition()
            }
        case let .restoring(identifier):
            let generated = activeMiMapsWatchfaceIdentifier
            activeMiMapsWatchfaceIdentifier = nil
            fullscreenNavigationEnabled = false
            fullscreenRiskAcknowledgedForSession = false
            watchfaceInstallationState = .restored(identifier: identifier)
            watchfaceUploadDescription = "đã khôi phục \(identifier)"
            appendEvent("Đã khôi phục mặt đồng hồ \(identifier)")
            if let generated, isGeneratedWatchfaceIdentifier(generated) {
                enqueueCommand(
                    MiBandWatchfaceProtocol.makeDeleteCommand(identifier: generated),
                    label: "xóa mặt MiMaps sau khôi phục \(generated)"
                )
            }
        default:
            appendEvent("Nhận ACK kích hoạt ngoài phiên chuyển mặt đồng hồ")
        }
    }

    private func processPendingRealtimeInstructionAfterTransition() {
        guard let instruction = pendingRealtimeInstruction else { return }
        pendingRealtimeInstruction = nil
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.queueFullscreenNavigationUpdate(instruction)
        }
    }

    /// Band 8 asks for an application icon only after receiving a notification
    /// whose package is not cached. Send that notification once as a primer,
    /// then resend the latest content after the requested pixel upload.
    private func beginPictureModeDelivery(
        command: Data,
        label: String,
        package: String,
        maneuver: NavigationManeuver
    ) {
        let attemptID = pendingPictureNotification?.id ?? UUID()
        let wasAlreadyRunning = pendingPictureNotification != nil
        pendingPictureNotification = PendingPictureNotification(
            id: attemptID,
            label: label,
            command: command,
            maneuver: maneuver,
            package: package
        )
        if wasAlreadyRunning {
            appendEvent("Đã gộp cập nhật picture mode; giữ lại chỉ dẫn mới nhất")
            return
        }
        startPendingPictureModeRequest()
    }

    private func startPendingPictureModeRequest() {
        guard let pending = pendingPictureNotification else { return }
        let attemptID = pending.id
        pictureModeAttemptID = attemptID
        lastIconPackageName = nil
        pictureModeDescription = "đang gửi notification mồi"
        iconUploadDescription = "chờ Band hỏi package \(pending.package)"
        appendEvent("Picture mode: gửi notification mồi để Band hỏi icon \(pending.package)")
        // Xiaomi's real protocol starts with a notification for an uncached
        // package. Only after receiving subtype 16 from the Band may the phone
        // reply with subtype 15 and open a type-50 data upload.
        enqueueCommand(
            pending.command,
            label: PictureModeFallback.bootstrapLabel
        )
        schedulePictureModeRequestTimeout(for: attemptID)
    }

    private func restartPendingPictureModeRequest() {
        guard let pending = pendingPictureNotification else { return }
        pendingPictureNotification = PendingPictureNotification(
            id: UUID(),
            label: pending.label,
            command: pending.command,
            maneuver: pending.maneuver,
            package: pending.package
        )
        startPendingPictureModeRequest()
    }

    private func schedulePictureModeRequestTimeout(for attemptID: UUID) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self,
                  self.pictureModeAttemptID == attemptID,
                  self.pendingPictureNotification?.id == attemptID,
                  self.dataUploadPhase == .idle else { return }
            self.uploadedIconManeuver = self.pendingPictureNotification?.maneuver
            if let pending = self.pendingPictureNotification {
                self.notificationIconCache.insert(
                    package: pending.package,
                    deviceIdentifier: self.connectedPeripheral?.identifier
                )
            }
            self.pictureModeDescription = "Band dùng icon đã cache; thông báo đã gửi"
            self.iconUploadDescription = "không cần upload lại"
            self.appendEvent(
                "Picture mode: Band không hỏi package sau 5 giây; xác nhận cache-hit "
                    + "và ghi nhớ cho các lần gửi realtime tiếp theo"
            )
            // The primer already contains the complete instruction. Clear the
            // negotiation without sending an identical notification twice.
            self.pendingPictureNotification = nil
            self.pictureModeAttemptID = nil
        }
    }

    private func deliverPendingPictureNotification() {
        guard let pending = pendingPictureNotification else { return }
        pendingPictureNotification = nil
        pictureModeAttemptID = nil
        enqueueCommand(pending.command, label: pending.label)
    }

    private func enqueueCommand(_ command: Data, label: String) {
        queuedCommands.append(QueuedCommand(id: UUID(), label: label, command: command))
        sendNextQueuedCommandIfPossible()
    }

    private func sendNextQueuedCommandIfPossible() {
        guard pendingCommand == nil, !queuedCommands.isEmpty else { return }
        guard canSendDirectNotifications,
              let peripheral = connectedPeripheral,
              let write = characteristicHandles[ProtocolCharacteristic.commandWrite],
              let sessionKeys = authenticationContext?.sessionKeys else {
            queuedCommands.removeAll()
            directNotificationState = .failed("Phiên bảo mật không còn sẵn sàng.")
            return
        }

        let item = queuedCommands.removeFirst()
        do {
            let frame = try MiBandSessionProtocol.makeEncryptedSingleFrame(
                command: item.command,
                sessionKeys: sessionKeys,
                counter: outgoingEncryptionCounter
            )
            let writeType: CBCharacteristicWriteType = write.properties.contains(.write)
                ? .withResponse
                : .withoutResponse
            let maximumLength = peripheral.maximumWriteValueLength(for: writeType)
            guard frame.count <= maximumLength else {
                directNotificationState = .failed(
                    "Thông báo \(frame.count) byte vượt giới hạn GATT \(maximumLength) byte."
                )
                appendEvent("Dừng gửi \(item.label): khung quá dài \(frame.count)/\(maximumLength) byte")
                sendNextQueuedCommandIfPossible()
                return
            }

            pendingCommand = item
            directNotificationState = .sending(item.label)
            writeValue(frame, to: write, peripheral: peripheral)
            sentCommandCount += 1
            appendEvent(
                "Gửi lệnh mã hóa #\(sentCommandCount), counter=\(outgoingEncryptionCounter), \(frame.count) byte: \(item.label)"
            )
            if outgoingEncryptionCounter == UInt16.max {
                outgoingEncryptionCounter = 0
            } else {
                outgoingEncryptionCounter += 1
            }
            scheduleCommandAcknowledgementTimeout(for: item.id)
        } catch {
            directNotificationState = .failed(error.localizedDescription)
            appendEvent("Không thể gửi \(item.label): \(error.localizedDescription)")
            sendNextQueuedCommandIfPossible()
        }
    }

    private func handleCommandAcknowledgement(_ result: UInt8) {
        guard let item = pendingCommand else { return }
        pendingCommand = nil
        if result == 0 {
            directNotificationState = .delivered(item.label)
            appendEvent("Band ACK lệnh trực tiếp: \(item.label)")
        } else {
            directNotificationState = .failed("Band trả ACK mã \(result) cho \(item.label).")
            appendEvent("Band từ chối lệnh \(item.label), ACK=\(result)")
            if isWatchfaceTransitionInProgress {
                watchfaceInstallationState = .failed(
                    "Band từ chối \(item.label), ACK=\(result)."
                )
                fullscreenNavigationEnabled = false
            }
        }
        sendNextQueuedCommandIfPossible()
        if pendingCommand == nil, queuedCommands.isEmpty, fullscreenNavigationEnabled {
            processPendingRealtimeInstructionAfterTransition()
        }
    }

    private func scheduleCommandAcknowledgementTimeout(for id: UUID) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, self.pendingCommand?.id == id else { return }
            let label = self.pendingCommand?.label ?? "lệnh"
            self.pendingCommand = nil
            self.directNotificationState = .failed("Band không ACK \(label).")
            self.appendEvent("Hết thời gian chờ Band ACK: \(label)")
            if self.isWatchfaceTransitionInProgress {
                self.watchfaceInstallationState = .failed("Band không ACK \(label).")
                self.fullscreenNavigationEnabled = false
            }
            self.sendNextQueuedCommandIfPossible()
        }
    }

    private func beginIconUpload(
        request: MiBandNotificationIconRequest,
        maneuver: NavigationManeuver?
    ) throws {
        guard request.status == 0 else {
            iconUploadDescription = "Band không yêu cầu upload (status=\(request.status))"
            pictureModeDescription = "Band dùng icon đã lưu; gửi thông báo"
            uploadedIconManeuver = maneuver
            if let package = lastIconPackageName {
                notificationIconCache.insert(
                    package: package,
                    deviceIdentifier: connectedPeripheral?.identifier
                )
            }
            appendEvent(iconUploadDescription)
            deliverPendingPictureNotification()
            return
        }
        guard dataUploadPhase == .idle else {
            appendEvent("Yêu cầu icon đến khi upload hiện tại đang chạy; tiếp tục phiên hiện tại")
            pictureModeDescription = "đang upload icon"
            return
        }
        let bytes = try MiBandManeuverIconRenderer.pixelData(
            maneuver: maneuver,
            size: Int(request.size),
            pixelFormat: Int(request.pixelFormat)
        )
        dataUploadManeuver = maneuver
        iconUploadDescription = "chuẩn bị \(bytes.count) byte"
        try beginDataUpload(bytes: bytes, purpose: .notificationIcon(maneuver))
    }

    private func beginDataUpload(bytes: Data, purpose: DataUploadPurpose) throws {
        guard dataUploadPhase == .idle else {
            throw MiBandDataUploadProtocolError.uploadAlreadyInProgress
        }
        guard let peripheral = connectedPeripheral,
              let characteristic = characteristicHandles[ProtocolCharacteristic.dataUpload] else {
            throw MiBandDataUploadProtocolError.malformedProtobuf
        }

        pendingUploadBytes = bytes
        dataUploadPurpose = purpose

        if characteristic.isNotifying {
            requestPendingDataUpload()
        } else {
            dataUploadPhase = .enablingNotifications
            appendEvent("Bật notify FE95/0055 để truyền \(purpose.noun)")
            peripheral.setNotifyValue(true, for: characteristic)
            scheduleDataUploadTimeout()
        }
    }

    private func requestPendingDataUpload() {
        guard let bytes = pendingUploadBytes,
              let purpose = dataUploadPurpose else { return }
        dataUploadPhase = .waitingRequestAcknowledgement
        updateDataUploadDescription("đang thương lượng upload \(bytes.count) byte")
        appendEvent("Yêu cầu Band mở phiên upload \(purpose.noun) \(bytes.count) byte")
        enqueueCommand(
            MiBandDataUploadProtocol.makeUploadRequest(
                type: purpose.type,
                bytes: bytes
            ),
            label: "yêu cầu upload \(purpose.noun)"
        )
        scheduleDataUploadTimeout()
    }

    private func handleDataUploadAcknowledgement(
        _ acknowledgement: MiBandDataUploadAcknowledgement
    ) throws {
        guard dataUploadPhase == .waitingRequestAcknowledgement,
              let bytes = pendingUploadBytes,
              let purpose = dataUploadPurpose else { return }
        dataUploadParts = try MiBandDataUploadProtocol.uploadParts(
            type: purpose.type,
            bytes: bytes,
            chunkSize: acknowledgement.chunkSize
        )
        nextDataUploadPartIndex = 0
        appendEvent(
            "Band chấp nhận \(purpose.noun); truyền \(dataUploadParts.count) phần, "
                + "chunk=\(acknowledgement.chunkSize)"
        )
        sendNextDataUploadPart()
    }

    private func sendNextDataUploadPart() {
        guard nextDataUploadPartIndex < dataUploadParts.count else {
            completeDataUpload()
            return
        }
        guard let peripheral = connectedPeripheral,
              let characteristic = characteristicHandles[ProtocolCharacteristic.dataUpload],
              let sessionKeys = authenticationContext?.sessionKeys else {
            failDataUpload("Kênh FE95/0055 không còn sẵn sàng.")
            return
        }

        do {
            let encrypted = try MiBandSessionProtocol.encryptAuxiliaryPayload(
                dataUploadParts[nextDataUploadPartIndex],
                sessionKeys: sessionKeys
            )
            let writeType = dataUploadWriteType(for: characteristic)
            let maximumLength = min(
                peripheral.maximumWriteValueLength(for: writeType),
                DataUploadTransport.maximumFrameLength
            )
            guard maximumLength > 8 else {
                failDataUpload("MTU của FE95/0055 quá nhỏ.")
                return
            }

            if encrypted.count + 6 <= maximumLength {
                var frame = Data([0, 0, 2, 1, 0, 0])
                frame.append(encrypted)
                writeDataUploadControlFrame(
                    frame,
                    writingPhase: .writingSingleFrame,
                    waitingPhase: .waitingSingleAcknowledgement,
                    characteristic: characteristic,
                    peripheral: peripheral
                )
            } else {
                let payloadSize = maximumLength - 2
                auxiliaryFrames = stride(from: 0, to: encrypted.count, by: payloadSize)
                    .enumerated()
                    .map { offset, start in
                        var frame = Data()
                        frame.appendLittleEndian(UInt16(offset + 1))
                        frame.append(encrypted[start..<min(start + payloadSize, encrypted.count)])
                        return frame
                    }
                pendingAuxiliaryFrameIndexes = Array(auxiliaryFrames.indices)
                var start = Data([0, 0, 0, 1])
                start.appendLittleEndian(UInt16(auxiliaryFrames.count))
                writeDataUploadControlFrame(
                    start,
                    writingPhase: .writingChunkStart,
                    waitingPhase: .waitingChunkStartAcknowledgement,
                    characteristic: characteristic,
                    peripheral: peripheral
                )
            }
            let mode = writeType == .withoutResponse ? "WNR" : "WR"
            let progress = Int(
                Double(nextDataUploadPartIndex) / Double(max(dataUploadParts.count, 1)) * 100
            )
            updateDataUploadDescription(
                "đang gửi phần \(nextDataUploadPartIndex + 1)/\(dataUploadParts.count), "
                    + "MTU=\(maximumLength), \(mode)"
            )
            if case .some(.watchface(identifier: _)) = dataUploadPurpose {
                watchfaceInstallationState = .uploading(progressPercent: progress)
            }
            appendEvent("FE95/0055 dùng \(mode), khung tối đa \(maximumLength) byte")
            scheduleDataUploadTimeout()
        } catch {
            failDataUpload(error.localizedDescription)
        }
    }

    private func dataUploadWriteType(for characteristic: CBCharacteristic) -> CBCharacteristicWriteType {
        characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
    }

    private func writeDataUploadControlFrame(
        _ frame: Data,
        writingPhase: DataUploadPhase,
        waitingPhase: DataUploadPhase,
        characteristic: CBCharacteristic,
        peripheral: CBPeripheral
    ) {
        let writeType = dataUploadWriteType(for: characteristic)
        dataUploadPhase = writingPhase
        if writeType == .withoutResponse, !peripheral.canSendWriteWithoutResponse {
            pendingDataUploadControlFrame = frame
            return
        }
        peripheral.writeValue(frame, for: characteristic, type: writeType)
        if writeType == .withoutResponse {
            dataUploadPhase = waitingPhase
        }
    }

    private func resumeDataUploadWithoutResponse(on peripheral: CBPeripheral) {
        guard let characteristic = characteristicHandles[ProtocolCharacteristic.dataUpload],
              dataUploadWriteType(for: characteristic) == .withoutResponse else { return }

        if let frame = pendingDataUploadControlFrame,
           peripheral.canSendWriteWithoutResponse {
            pendingDataUploadControlFrame = nil
            peripheral.writeValue(frame, for: characteristic, type: .withoutResponse)
            switch dataUploadPhase {
            case .writingSingleFrame:
                dataUploadPhase = .waitingSingleAcknowledgement
            case .writingChunkStart:
                dataUploadPhase = .waitingChunkStartAcknowledgement
            default:
                break
            }
        }

        if dataUploadPhase == .writingChunks {
            sendAvailableAuxiliaryFrames()
        }
    }

    private func sendAvailableAuxiliaryFrames() {
        guard let peripheral = connectedPeripheral,
              let characteristic = characteristicHandles[ProtocolCharacteristic.dataUpload] else {
            failDataUpload("Kênh FE95/0055 không còn sẵn sàng.")
            return
        }

        let writeType = dataUploadWriteType(for: characteristic)
        dataUploadPhase = .writingChunks
        while let frameIndex = pendingAuxiliaryFrameIndexes.first {
            if writeType == .withoutResponse, !peripheral.canSendWriteWithoutResponse {
                return
            }
            pendingAuxiliaryFrameIndexes.removeFirst()
            peripheral.writeValue(auxiliaryFrames[frameIndex], for: characteristic, type: writeType)
            if writeType == .withResponse {
                return
            }
        }
        dataUploadPhase = .waitingChunkEndAcknowledgement
        appendEvent(
            "Đã xếp đủ \(auxiliaryFrames.count) frame "
                + "\(dataUploadPurpose?.noun ?? "dữ liệu") vào hàng đợi Bluetooth"
        )
    }

    private func handleDataUploadChannelPacket(_ data: Data) {
        if data == Data([0, 0, 1, 1]) {
            guard dataUploadPhase == .waitingChunkStartAcknowledgement
                    || dataUploadPhase == .writingChunkStart else { return }
            appendEvent("Band ACK bắt đầu khối \(dataUploadPurpose?.noun ?? "dữ liệu")")
            sendAvailableAuxiliaryFrames()
            return
        }
        if data == Data([0, 0, 1, 0]) {
            guard dataUploadPhase == .waitingChunkEndAcknowledgement
                    || dataUploadPhase == .writingChunks else { return }
            completeCurrentDataUploadPart()
            return
        }
        if let requestedIndexes = MiBandDataUploadProtocol.missingChunkIndexes(from: data) {
            guard dataUploadPhase == .waitingChunkEndAcknowledgement
                    || dataUploadPhase == .writingChunks else { return }
            let validIndexes = requestedIndexes
                .map { $0 - 1 }
                .filter { auxiliaryFrames.indices.contains($0) }
            guard !validIndexes.isEmpty else {
                failDataUpload("Band yêu cầu lại frame không hợp lệ: \(requestedIndexes).")
                return
            }
            pendingAuxiliaryFrameIndexes = validIndexes
            appendEvent(
                "Band yêu cầu gửi lại frame \(dataUploadPurpose?.noun ?? "dữ liệu"): "
                    + requestedIndexes.map(String.init).joined(separator: ", ")
            )
            sendAvailableAuxiliaryFrames()
            return
        }
        if data.count == 4, data.starts(with: [0, 0, 3]) {
            guard dataUploadPhase == .waitingSingleAcknowledgement
                    || dataUploadPhase == .writingSingleFrame else { return }
            guard data.last == 0 else {
                failDataUpload("Band từ chối khối dữ liệu, ACK=\(data.last ?? 255).")
                return
            }
            completeCurrentDataUploadPart()
            return
        }
        appendEvent(
            "Phản hồi FE95/0055 chưa nhận dạng: \(MiBandCapturedPacket.preview(data, limit: 40))"
        )
    }

    private func completeCurrentDataUploadPart() {
        let noun = dataUploadPurpose?.noun ?? "dữ liệu"
        appendEvent("Band nhận phần \(noun) \(nextDataUploadPartIndex + 1)/\(dataUploadParts.count)")
        nextDataUploadPartIndex += 1
        auxiliaryFrames = []
        pendingAuxiliaryFrameIndexes = []
        pendingDataUploadControlFrame = nil
        sendNextDataUploadPart()
    }

    private func completeDataUpload() {
        let byteCount = pendingUploadBytes?.count ?? 0
        let purpose = dataUploadPurpose
        let completedManeuver = dataUploadManeuver
        appendEvent("Upload \(purpose?.noun ?? "dữ liệu") hoàn tất: \(byteCount) byte")
        resetDataUpload(description: "hoàn tất \(byteCount) byte")

        switch purpose {
        case .some(.notificationIcon(_)):
            uploadedIconManeuver = completedManeuver
            if let package = lastIconPackageName {
                notificationIconCache.insert(
                    package: package,
                    deviceIdentifier: connectedPeripheral?.identifier
                )
            }
            let followUp = MiBandIconUploadFollowUp.resolve(
                pendingManeuver: pendingPictureNotification?.maneuver,
                completedManeuver: completedManeuver
            )
            switch followUp {
            case .deliverPendingNotification:
                pictureModeDescription = "icon đã sẵn sàng; gửi thông báo"
                deliverPendingPictureNotification()
            case .restartForUpdatedManeuver:
                pictureModeAttemptID = nil
                appendEvent("Hướng rẽ đã đổi trong lúc upload; mở picture mode cho chỉ dẫn mới nhất")
                restartPendingPictureModeRequest()
            case .cacheAdditionalSize:
                pictureModeAttemptID = nil
                pictureModeDescription = "đã lưu thêm icon \(byteCount) byte vào cache"
                appendEvent("Đã hoàn tất kích thước icon phụ; không gửi lặp thông báo")
            }
        case let .some(.watchface(identifier)):
            if restoreRequestedAfterTransfer,
               let restoreIdentifier = previousWatchfaceIdentifier {
                restoreRequestedAfterTransfer = false
                watchfaceInstallationState = .restoring(identifier: restoreIdentifier)
                watchfaceUploadDescription = "đã upload nhưng bỏ kích hoạt; đang khôi phục"
                enqueueCommand(
                    MiBandWatchfaceProtocol.makeSetCommand(identifier: restoreIdentifier),
                    label: "khôi phục mặt đồng hồ \(restoreIdentifier)"
                )
                enqueueCommand(
                    MiBandWatchfaceProtocol.makeDeleteCommand(identifier: identifier),
                    label: "xóa gói MiMaps chưa kích hoạt \(identifier)"
                )
            } else {
                watchfaceInstallationState = .activating(identifier: identifier)
                watchfaceUploadDescription = "upload xong; đang kích hoạt \(identifier)"
                enqueueCommand(
                    MiBandWatchfaceProtocol.makeSetCommand(identifier: identifier),
                    label: "kích hoạt mặt đồng hồ \(identifier)"
                )
            }
        case .none:
            break
        }
    }

    private func handleSuccessfulDataChannelWrite() {
        switch dataUploadPhase {
        case .writingSingleFrame:
            dataUploadPhase = .waitingSingleAcknowledgement
        case .writingChunkStart:
            dataUploadPhase = .waitingChunkStartAcknowledgement
        case .writingChunks:
            sendAvailableAuxiliaryFrames()
        default:
            break
        }
    }

    private func scheduleDataUploadTimeout() {
        let attemptID = UUID()
        dataUploadAttemptID = attemptID
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard let self,
                  self.dataUploadAttemptID == attemptID,
                  self.dataUploadPhase != .idle else { return }
            self.failDataUpload("Hết thời gian chờ truyền dữ liệu.")
        }
    }

    private func failDataUpload(_ message: String) {
        let purpose = dataUploadPurpose
        appendEvent("Upload \(purpose?.noun ?? "dữ liệu") thất bại: \(message)")
        resetDataUpload(description: "lỗi: \(message)")
        switch purpose {
        case .some(.notificationIcon(_)):
            pictureModeDescription = "upload icon lỗi; gửi text dự phòng"
            deliverPendingPictureNotification()
        case .some(.watchface(identifier: _)):
            watchfaceInstallationState = .failed(message)
            watchfaceUploadDescription = "lỗi: \(message)"
            fullscreenNavigationEnabled = false
        case .none:
            break
        }
    }

    private func resetDataUpload(description: String) {
        let purpose = dataUploadPurpose
        pendingUploadBytes = nil
        dataUploadParts = []
        nextDataUploadPartIndex = 0
        auxiliaryFrames = []
        pendingAuxiliaryFrameIndexes = []
        pendingDataUploadControlFrame = nil
        dataUploadAttemptID = nil
        dataUploadPhase = .idle
        dataUploadManeuver = nil
        dataUploadPurpose = nil
        switch purpose {
        case .some(.notificationIcon(_)), .none:
            iconUploadDescription = description
        case .some(.watchface(identifier: _)):
            watchfaceUploadDescription = description
        }
    }

    private func updateDataUploadDescription(_ description: String) {
        switch dataUploadPurpose {
        case .some(.notificationIcon(_)), .none:
            iconUploadDescription = description
        case .some(.watchface(identifier: _)):
            watchfaceUploadDescription = description
        }
    }

    private func resetSecureSession() {
        authenticationContext = nil
        outgoingEncryptionCounter = 1
        queuedCommands.removeAll()
        pendingCommand = nil
        directNotificationState = .unavailable
        decryptedPacketCount = 0
        sentCommandCount = 0
        lastDecryptedCommandPreview = nil
        lastIconRequestDescription = nil
        lastNavigationManeuver = nil
        uploadedIconManeuver = nil
        activeNavigationNotificationIdentifier = nil
        activeNavigationPackage = nil
        lastIconPackageName = nil
        pendingPictureNotification = nil
        pictureModeAttemptID = nil
        pictureModeDescription = "chưa bắt đầu"
        resetDataUpload(description: "chưa bắt đầu")
        preparedWatchfacePackage = nil
        pendingRealtimeInstruction = nil
        lastFullscreenInstruction = nil
        lastFullscreenUpdateTimestamp = nil
        activeMiMapsWatchfaceIdentifier = nil
        fullscreenRiskAcknowledgedForSession = false
        restoreRequestedAfterTransfer = false
        fullscreenNavigationEnabled = false
        watchfaceInstallationState = .unavailable
        watchfaceUploadDescription = "chưa bắt đầu"
    }

    private func writeValue(_ data: Data, to characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.write)
            ? .withResponse
            : .withoutResponse
        peripheral.writeValue(data, for: characteristic, type: type)
    }

    private func scheduleAuthenticationTimeout(for attemptID: UUID) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self,
                  self.authenticationAttemptID == attemptID,
                  self.authenticationState.isInProgress else { return }
            self.failAuthentication("Hết thời gian chờ. Hãy đóng hẳn Mi Fitness rồi thử lại.")
        }
    }

    private func failAuthentication(_ message: String) {
        authenticationAttemptID = nil
        resetSecureSession()
        authenticationNotificationStage = .idle
        authenticationState = .failed(message)
        appendEvent("Xác thực thất bại: \(message)")
    }

    private static func characteristicKey(service: CBUUID, characteristic: CBUUID) -> String {
        "\(service.uuidString.uppercased())/\(characteristic.uuidString.uppercased())"
    }

    private static func isProtocolNotifyCandidate(_ characteristic: CBCharacteristic) -> Bool {
        guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate),
              let service = characteristic.service?.uuid.uuidString.uppercased() else {
            return false
        }
        return service == "FE95" || service == "FDAB"
    }

    private static func bluetoothDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: "chưa xác định"
        case .resetting: "đang khởi động lại"
        case .unsupported: "không được hỗ trợ"
        case .unauthorized: "chưa được cấp quyền"
        case .poweredOff: "đang tắt"
        case .poweredOn: "đang bật"
        @unknown default: "trạng thái mới"
        }
    }

    private static func propertyNames(_ properties: CBCharacteristicProperties) -> [String] {
        var names: [String] = []
        if properties.contains(.broadcast) { names.append("broadcast") }
        if properties.contains(.read) { names.append("read") }
        if properties.contains(.writeWithoutResponse) { names.append("writeWithoutResponse") }
        if properties.contains(.write) { names.append("write") }
        if properties.contains(.notify) { names.append("notify") }
        if properties.contains(.indicate) { names.append("indicate") }
        if properties.contains(.authenticatedSignedWrites) { names.append("signedWrite") }
        if properties.contains(.extendedProperties) { names.append("extended") }
        if properties.contains(.notifyEncryptionRequired) { names.append("notifyEncrypted") }
        if properties.contains(.indicateEncryptionRequired) { names.append("indicateEncrypted") }
        return names
    }
}

extension MiBandDirectConnection: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        appendEvent("Bluetooth chuyển sang: \(Self.bluetoothDescription(central.state))")
        guard central.state == .poweredOn else {
            state = .bluetoothUnavailable(Self.bluetoothDescription(central.state))
            return
        }

        if case .bluetoothUnavailable = state { state = .idle }
        if hasSavedDevice {
            appendEvent("Thiết bị đã lưu sẵn sàng; chờ người dùng kết nối thủ công")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name
        guard MiBandDeviceMatcher.isMiBand8(name: name) else { return }

        let resolvedName = name ?? "Mi Band 8"
        peripherals[peripheral.identifier] = peripheral
        let device = MiBandDevice(
            id: peripheral.identifier,
            name: resolvedName,
            rssi: RSSI.intValue,
            isSupportedModel: true
        )

        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
            appendEvent("Tìm thấy \(resolvedName), RSSI \(RSSI.intValue)")
        }
        discoveredDevices.sort { $0.rssi > $1.rssi }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        lastConnectedDeviceName = peripheral.name ?? "Mi Band 8"
        lastConnectedDeviceIdentifier = peripheral.identifier
        characteristics = []
        characteristicHandles = [:]
        pendingServiceUUIDs = []
        authenticationAttemptID = nil
        resetSecureSession()
        authenticationNotificationStage = .idle
        authenticationState = savedKeyFingerprint == nil ? .missingKey : .ready
        peripheral.delegate = self
        let name = peripheral.name ?? "Mi Band 8"
        state = .discovering(name)
        appendEvent("Đã kết nối; bắt đầu khám phá service")
        peripheral.discoverServices(nil)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        state = .failed(error?.localizedDescription ?? "Không thể kết nối.")
        appendEvent("Kết nối thất bại: \(error?.localizedDescription ?? "không rõ")")
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let interruptedAuthentication = authenticationState.isInProgress
        let interruptedPhase = authenticationNotificationStage.rawValue
        connectedPeripheral = nil
        pendingServiceUUIDs = []
        characteristicHandles = [:]
        authenticationAttemptID = nil
        resetSecureSession()
        authenticationNotificationStage = .idle
        if interruptedAuthentication {
            authenticationState = .failed("Band ngắt kết nối khi đang \(interruptedPhase).")
        } else if authenticationState == .authenticated {
            authenticationState = .failed("Band đã ngắt kết nối sau xác thực.")
        } else {
            authenticationState = savedKeyFingerprint == nil ? .missingKey : .ready
        }
        isCapturingPackets = false
        state = error.map { .failed($0.localizedDescription) } ?? .disconnected
        if interruptedAuthentication {
            appendEvent("Xác thực bị gián đoạn tại bước: \(interruptedPhase)")
        }
        appendEvent("Đã ngắt kết nối\(error.map { ": \($0.localizedDescription)" } ?? "")")
    }
}

extension MiBandDirectConnection: @preconcurrency CBPeripheralDelegate {
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        resumeDataUploadWithoutResponse(on: peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            state = .failed(error.localizedDescription)
            appendEvent("Lỗi khám phá service: \(error.localizedDescription)")
            return
        }

        let services = peripheral.services ?? []
        pendingServiceUUIDs = Set(services.map(\.uuid))
        appendEvent("Tìm thấy \(services.count) service")
        guard !services.isEmpty else {
            finishDiscoveryIfPossible()
            return
        }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        defer {
            pendingServiceUUIDs.remove(service.uuid)
            finishDiscoveryIfPossible()
        }

        if let error {
            appendEvent("Lỗi characteristic \(service.uuid.uuidString): \(error.localizedDescription)")
            return
        }

        for characteristic in service.characteristics ?? [] {
            characteristicHandles[
                Self.characteristicKey(service: service.uuid, characteristic: characteristic.uuid)
            ] = characteristic
            characteristics.append(
                MiBandGATTCharacteristic(
                    serviceUUID: service.uuid.uuidString,
                    characteristicUUID: characteristic.uuid.uuidString,
                    properties: Self.propertyNames(characteristic.properties)
                )
            )
        }
    }


    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let service = characteristic.service?.uuid.uuidString ?? "?"
        let key = characteristic.service.map {
            Self.characteristicKey(service: $0.uuid, characteristic: characteristic.uuid)
        }
        if let error {
            appendEvent("Không thể bật notify \(service)/\(characteristic.uuid.uuidString): \(error.localizedDescription)")
            if key == ProtocolCharacteristic.dataUpload,
               dataUploadPhase == .enablingNotifications {
                failDataUpload(error.localizedDescription)
            }
            return
        }
        appendEvent("Notify \(characteristic.isNotifying ? "ON" : "OFF") \(service)/\(characteristic.uuid.uuidString)")
        guard characteristic.isNotifying,
              let serviceUUID = characteristic.service?.uuid else { return }
        let resolvedKey = Self.characteristicKey(service: serviceUUID, characteristic: characteristic.uuid)
        advanceAuthenticationSubscriptions(notifiedKey: resolvedKey, peripheral: peripheral)
        if resolvedKey == ProtocolCharacteristic.dataUpload,
           dataUploadPhase == .enablingNotifications {
            requestPendingDataUpload()
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let serviceUUID = characteristic.service?.uuid else { return }
        let key = Self.characteristicKey(service: serviceUUID, characteristic: characteristic.uuid)
        if let error {
            appendEvent("Ghi \(key) thất bại: \(error.localizedDescription)")
            if authenticationState.isInProgress {
                failAuthentication("Không thể ghi \(key): \(error.localizedDescription)")
            } else if key == ProtocolCharacteristic.dataUpload {
                failDataUpload(error.localizedDescription)
            } else if key == ProtocolCharacteristic.commandWrite,
                      let item = pendingCommand {
                pendingCommand = nil
                directNotificationState = .failed(error.localizedDescription)
                appendEvent("Gửi trực tiếp \(item.label) thất bại ở tầng GATT")
                sendNextQueuedCommandIfPossible()
            }
        } else {
            if authenticationState.isInProgress {
                appendEvent("Ghi \(key) thành công ở tầng GATT")
            }
            if key == ProtocolCharacteristic.dataUpload {
                handleSuccessfulDataChannelWrite()
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let service = characteristic.service?.uuid.uuidString ?? "?"
        if let error {
            appendEvent("Lỗi nhận dữ liệu \(service)/\(characteristic.uuid.uuidString): \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else { return }
        if let serviceUUID = characteristic.service?.uuid {
            let key = Self.characteristicKey(
                service: serviceUUID,
                characteristic: characteristic.uuid
            )
            if key == "180A/2A26" {
                firmwareVersion = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
                appendEvent("Firmware Band: \(firmwareVersion ?? "không đọc được")")
                return
            }
            if key == "180F/2A19", let level = data.first {
                batteryLevel = Int(level)
                appendEvent("Pin Band: \(level)%")
                return
            }
        }
        if isCapturingPackets {
            capturedPackets.append(
                MiBandCapturedPacket(
                    timestamp: now(),
                    serviceUUID: service,
                    characteristicUUID: characteristic.uuid.uuidString,
                    data: data
                )
            )
            if capturedPackets.count > 250 {
                capturedPackets.removeFirst(capturedPackets.count - 250)
            }
        }
        handleProtocolPacket(data, characteristic: characteristic, peripheral: peripheral)
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { append(contentsOf: $0) }
    }
}
