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
    private let defaults: UserDefaults
    private let now: () -> Date
    private let credentialStore: MiBandCredentialStoring

    private struct AuthenticationContext {
        let secretKey: Data
        let phoneNonce: Data
        var sessionKeys: MiBandSessionKeys?
    }

    private enum ProtocolCharacteristic {
        static let commandRead = "FE95/0051"
        static let commandWrite = "FE95/0052"
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
        guard state.isReady, let peripheral = connectedPeripheral else {
            failAuthentication("Thiết bị chưa sẵn sàng.")
            return
        }
        guard let storedKey = credentialStore.loadAuthenticationKey() else {
            authenticationState = .missingKey
            appendEvent("Không thể xác thực: chưa có khóa trong Keychain")
            return
        }
        guard let commandRead = characteristicHandles[ProtocolCharacteristic.commandRead],
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
            peripheral.setNotifyValue(true, for: commandRead)
            peripheral.setNotifyValue(true, for: commandWrite)
            appendEvent("Bắt đầu xác thực cục bộ; đang mở kênh FE95 bảo mật")
            tryStartAuthenticationIfSubscribed()
            scheduleAuthenticationTimeout(for: attemptID)
        } catch {
            failAuthentication(error.localizedDescription)
        }
    }

    func forgetDevice() {
        disconnect()
        defaults.removeObject(forKey: StorageKey.peripheralIdentifier)
        connectedPeripheral = nil
        characteristics = []
        characteristicHandles = [:]
        capturedPackets = []
        isCapturingPackets = false
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
            "Device: \(device?.name ?? "—")",
            "Identifier: \(device?.identifier.uuidString ?? "—")",
            "GATT characteristics: \(characteristics.count)",
            "Authentication key: \(savedKeyFingerprint == nil ? "not configured" : "configured")",
            "Authentication: \(authenticationState.localizedDescription)",
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

    private func tryStartAuthenticationIfSubscribed() {
        guard authenticationState == .subscribing,
              let peripheral = connectedPeripheral,
              let read = characteristicHandles[ProtocolCharacteristic.commandRead],
              let write = characteristicHandles[ProtocolCharacteristic.commandWrite],
              read.isNotifying, write.isNotifying,
              let context = authenticationContext else { return }
        do {
            let command = try MiBandAuthProtocol.makePhoneNonceCommand(phoneNonce: context.phoneNonce)
            writeValue(MiBandAuthProtocol.plaintextFrame(command), to: write, peripheral: peripheral)
            authenticationState = .waitingForWatch
            appendEvent("Đã gửi thử thách xác thực; đang chờ nonce của vòng")
        } catch {
            failAuthentication(error.localizedDescription)
        }
    }

    private func handleProtocolPacket(
        _ data: Data,
        characteristic: CBCharacteristic,
        peripheral: CBPeripheral
    ) {
        guard let service = characteristic.service?.uuid,
              Self.characteristicKey(service: service, characteristic: characteristic.uuid)
                == ProtocolCharacteristic.commandRead,
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
                authenticationState = .authenticated
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
        authenticationContext = nil
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
        reconnectSavedDevice()
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
        characteristics = []
        characteristicHandles = [:]
        pendingServiceUUIDs = []
        authenticationAttemptID = nil
        authenticationContext = nil
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
        connectedPeripheral = nil
        pendingServiceUUIDs = []
        characteristicHandles = [:]
        characteristics = []
        authenticationAttemptID = nil
        authenticationContext = nil
        authenticationState = savedKeyFingerprint == nil ? .missingKey : .ready
        isCapturingPackets = false
        state = error.map { .failed($0.localizedDescription) } ?? .disconnected
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
        if let error {
            appendEvent("Không thể bật notify \(service)/\(characteristic.uuid.uuidString): \(error.localizedDescription)")
            return
        }
        appendEvent("Notify \(characteristic.isNotifying ? "ON" : "OFF") \(service)/\(characteristic.uuid.uuidString)")
        tryStartAuthenticationIfSubscribed()
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
