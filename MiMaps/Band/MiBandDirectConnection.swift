@preconcurrency import CoreBluetooth
import Foundation

@MainActor
final class MiBandDirectConnection: NSObject, ObservableObject {
    @Published private(set) var state: MiBandConnectionState = .idle
    @Published private(set) var discoveredDevices: [MiBandDevice] = []
    @Published private(set) var characteristics: [MiBandGATTCharacteristic] = []
    @Published private(set) var eventLog: [String] = []

    private enum StorageKey {
        static let peripheralIdentifier = "directMiBandPeripheralIdentifier"
    }

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var pendingServiceUUIDs: Set<CBUUID> = []
    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        super.init()
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

    func forgetDevice() {
        disconnect()
        defaults.removeObject(forKey: StorageKey.peripheralIdentifier)
        connectedPeripheral = nil
        characteristics = []
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
            ""
        ]

        let gatt = characteristics.map { item in
            "\(item.serviceUUID) / \(item.characteristicUUID) [\(item.properties.joined(separator: ", "))]"
        }
        let events = ["", "Events:"] + eventLog
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
            characteristics.append(
                MiBandGATTCharacteristic(
                    serviceUUID: service.uuid.uuidString,
                    characteristicUUID: characteristic.uuid.uuidString,
                    properties: Self.propertyNames(characteristic.properties)
                )
            )
        }
    }
}

