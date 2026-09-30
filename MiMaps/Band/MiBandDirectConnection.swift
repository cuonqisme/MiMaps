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

    private enum StorageKey {
        static let peripheralIdentifier = "directMiBandPeripheralIdentifier"
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
    private var nextNotificationIdentifier: UInt32 = 1
    private var queuedCommands: [QueuedCommand] = []
    private var pendingCommand: QueuedCommand?
    private var lastNavigationManeuver: NavigationManeuver?
    private var lastIconPackageName: String?
    private var pendingIconBytes: Data?
    private var dataUploadParts: [Data] = []
    private var nextDataUploadPartIndex = 0
    private var auxiliaryFrames: [Data] = []
    private var nextAuxiliaryFrameIndex = 0
    private var dataUploadAttemptID: UUID?
    private var dataUploadPhase: DataUploadPhase = .idle
    private let defaults: UserDefaults
    private let now: () -> Date
    private let credentialStore: MiBandCredentialStoring

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

    private enum ProtocolCharacteristic {
        static let commandRead = "FE95/0051"
        static let commandWrite = "FE95/0052"
        static let dataUpload = "FE95/0055"
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
        let command = MiBandNotificationProtocol.makeNotificationCommand(
            id: nextNotificationIdentifier,
            title: title,
            body: body,
            date: now(),
            packageName: MiBandManeuverIconRenderer.packageName(for: maneuver)
        )
        nextNotificationIdentifier &+= 1
        if nextNotificationIdentifier == 0 { nextNotificationIdentifier = 1 }
        lastNavigationManeuver = maneuver
        enqueueCommand(command, label: label)
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
            "Decrypted session packets: \(decryptedPacketCount)",
            "Last decrypted command: \(lastDecryptedCommandPreview ?? "—")",
            "Last icon request: \(lastIconRequestDescription ?? "—")",
            "Icon upload: \(iconUploadDescription)",
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

            if let package = try MiBandNotificationIconProtocol.packageQuery(from: command) {
                lastIconPackageName = package
                lastIconRequestDescription = "query package=\(package)"
                appendEvent("Band yêu cầu icon cho package \(package); gửi phản hồi an toàn")
                enqueueCommand(
                    MiBandNotificationIconProtocol.makePackageReply(package: package),
                    label: "phản hồi icon \(package)"
                )
            } else if let request = try MiBandNotificationIconProtocol.iconRequest(from: command) {
                let requestedManeuver = lastIconPackageName.flatMap {
                    MiBandManeuverIconRenderer.maneuver(forPackageName: $0)
                } ?? lastNavigationManeuver
                let maneuver = requestedManeuver.map { String(describing: $0) } ?? "unknown"
                lastIconRequestDescription = "status=\(request.status), format=\(request.pixelFormat), size=\(request.size), maneuver=\(maneuver)"
                appendEvent("Band yêu cầu dữ liệu icon: \(lastIconRequestDescription ?? "—")")
                try beginIconUpload(request: request, maneuver: requestedManeuver)
            } else if let acknowledgement = try MiBandDataUploadProtocol.acknowledgement(from: command) {
                try handleDataUploadAcknowledgement(acknowledgement)
            }
        } catch {
            directNotificationState = .failed(error.localizedDescription)
            appendEvent("Đã ACK nhưng không giải mã được gói phiên: \(error.localizedDescription)")
        }
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
        }
        sendNextQueuedCommandIfPossible()
    }

    private func scheduleCommandAcknowledgementTimeout(for id: UUID) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, self.pendingCommand?.id == id else { return }
            let label = self.pendingCommand?.label ?? "lệnh"
            self.pendingCommand = nil
            self.directNotificationState = .failed("Band không ACK \(label).")
            self.appendEvent("Hết thời gian chờ Band ACK: \(label)")
            self.sendNextQueuedCommandIfPossible()
        }
    }

    private func beginIconUpload(
        request: MiBandNotificationIconRequest,
        maneuver: NavigationManeuver?
    ) throws {
        guard request.status == 0 else {
            iconUploadDescription = "Band không yêu cầu upload (status=\(request.status))"
            appendEvent(iconUploadDescription)
            return
        }
        guard dataUploadPhase == .idle else {
            appendEvent("Bỏ qua yêu cầu icon mới vì một upload khác đang chạy")
            return
        }
        guard let peripheral = connectedPeripheral,
              let characteristic = characteristicHandles[ProtocolCharacteristic.dataUpload] else {
            throw MiBandDataUploadProtocolError.malformedProtobuf
        }

        pendingIconBytes = try MiBandManeuverIconRenderer.pixelData(
            maneuver: maneuver,
            size: Int(request.size),
            pixelFormat: Int(request.pixelFormat)
        )
        dataUploadAttemptID = UUID()
        iconUploadDescription = "chuẩn bị \(pendingIconBytes?.count ?? 0) byte"

        if characteristic.isNotifying {
            requestPendingIconUpload()
        } else {
            dataUploadPhase = .enablingNotifications
            appendEvent("Bật notify FE95/0055 để truyền pixel icon")
            peripheral.setNotifyValue(true, for: characteristic)
            scheduleDataUploadTimeout()
        }
    }

    private func requestPendingIconUpload() {
        guard let bytes = pendingIconBytes else { return }
        dataUploadPhase = .waitingRequestAcknowledgement
        iconUploadDescription = "đang thương lượng upload \(bytes.count) byte"
        appendEvent("Yêu cầu Band mở phiên upload icon \(bytes.count) byte")
        enqueueCommand(
            MiBandDataUploadProtocol.makeUploadRequest(
                type: MiBandDataUploadProtocol.notificationIconType,
                bytes: bytes
            ),
            label: "yêu cầu upload icon"
        )
        scheduleDataUploadTimeout()
    }

    private func handleDataUploadAcknowledgement(
        _ acknowledgement: MiBandDataUploadAcknowledgement
    ) throws {
        guard dataUploadPhase == .waitingRequestAcknowledgement,
              let bytes = pendingIconBytes else { return }
        dataUploadParts = try MiBandDataUploadProtocol.uploadParts(
            type: MiBandDataUploadProtocol.notificationIconType,
            bytes: bytes,
            chunkSize: acknowledgement.chunkSize
        )
        nextDataUploadPartIndex = 0
        appendEvent(
            "Band chấp nhận icon; truyền \(dataUploadParts.count) phần, chunk=\(acknowledgement.chunkSize)"
        )
        sendNextDataUploadPart()
    }

    private func sendNextDataUploadPart() {
        guard nextDataUploadPartIndex < dataUploadParts.count else {
            let byteCount = pendingIconBytes?.count ?? 0
            appendEvent("Upload pixel icon hoàn tất: \(byteCount) byte")
            resetDataUpload(description: "hoàn tất \(byteCount) byte")
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
            let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write)
                ? .withResponse
                : .withoutResponse
            let maximumLength = peripheral.maximumWriteValueLength(for: writeType)
            guard maximumLength > 8 else {
                failDataUpload("MTU của FE95/0055 quá nhỏ.")
                return
            }

            if encrypted.count + 6 <= maximumLength {
                var frame = Data([0, 0, 2, 1, 0, 0])
                frame.append(encrypted)
                dataUploadPhase = .writingSingleFrame
                writeValue(frame, to: characteristic, peripheral: peripheral)
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
                nextAuxiliaryFrameIndex = 0
                var start = Data([0, 0, 0, 1])
                start.appendLittleEndian(UInt16(auxiliaryFrames.count))
                dataUploadPhase = .writingChunkStart
                writeValue(start, to: characteristic, peripheral: peripheral)
            }
            iconUploadDescription = "đang gửi phần \(nextDataUploadPartIndex + 1)/\(dataUploadParts.count)"
            scheduleDataUploadTimeout()
        } catch {
            failDataUpload(error.localizedDescription)
        }
    }

    private func sendNextAuxiliaryFrame() {
        guard nextAuxiliaryFrameIndex < auxiliaryFrames.count,
              let peripheral = connectedPeripheral,
              let characteristic = characteristicHandles[ProtocolCharacteristic.dataUpload] else {
            dataUploadPhase = .waitingChunkEndAcknowledgement
            return
        }
        let frame = auxiliaryFrames[nextAuxiliaryFrameIndex]
        nextAuxiliaryFrameIndex += 1
        dataUploadPhase = .writingChunks
        writeValue(frame, to: characteristic, peripheral: peripheral)
    }

    private func handleDataUploadChannelPacket(_ data: Data) {
        if data == Data([0, 0, 1, 1]) {
            guard dataUploadPhase == .waitingChunkStartAcknowledgement
                    || dataUploadPhase == .writingChunkStart else { return }
            appendEvent("Band ACK bắt đầu khối icon")
            sendNextAuxiliaryFrame()
            return
        }
        if data == Data([0, 0, 1, 0]) {
            guard dataUploadPhase == .waitingChunkEndAcknowledgement
                    || dataUploadPhase == .writingChunks else { return }
            completeCurrentDataUploadPart()
            return
        }
        if data.count == 4, data.starts(with: [0, 0, 3]) {
            guard dataUploadPhase == .waitingSingleAcknowledgement
                    || dataUploadPhase == .writingSingleFrame else { return }
            guard data.last == 0 else {
                failDataUpload("Band từ chối khối icon, ACK=\(data.last ?? 255).")
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
        appendEvent("Band nhận phần icon \(nextDataUploadPartIndex + 1)/\(dataUploadParts.count)")
        nextDataUploadPartIndex += 1
        auxiliaryFrames = []
        nextAuxiliaryFrameIndex = 0
        sendNextDataUploadPart()
    }

    private func handleSuccessfulDataChannelWrite() {
        switch dataUploadPhase {
        case .writingSingleFrame:
            dataUploadPhase = .waitingSingleAcknowledgement
        case .writingChunkStart:
            dataUploadPhase = .waitingChunkStartAcknowledgement
        case .writingChunks:
            if nextAuxiliaryFrameIndex < auxiliaryFrames.count {
                sendNextAuxiliaryFrame()
            } else {
                dataUploadPhase = .waitingChunkEndAcknowledgement
            }
        default:
            break
        }
    }

    private func scheduleDataUploadTimeout() {
        guard let attemptID = dataUploadAttemptID else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self,
                  self.dataUploadAttemptID == attemptID,
                  self.dataUploadPhase != .idle else { return }
            self.failDataUpload("Hết thời gian chờ truyền icon.")
        }
    }

    private func failDataUpload(_ message: String) {
        appendEvent("Upload icon thất bại: \(message)")
        resetDataUpload(description: "lỗi: \(message)")
    }

    private func resetDataUpload(description: String) {
        pendingIconBytes = nil
        dataUploadParts = []
        nextDataUploadPartIndex = 0
        auxiliaryFrames = []
        nextAuxiliaryFrameIndex = 0
        dataUploadAttemptID = nil
        dataUploadPhase = .idle
        iconUploadDescription = description
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
        lastIconPackageName = nil
        resetDataUpload(description: "chưa bắt đầu")
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
            requestPendingIconUpload()
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
