import SwiftUI

struct BandConnectionView: View {
    @ObservedObject private var connection: MiBandDirectConnection
    @State private var authenticationKey = ""
    @State private var keyError: String?

    init(connection: MiBandDirectConnection) {
        _connection = ObservedObject(wrappedValue: connection)
    }

    var body: some View {
        List {
            Section("Kết nối trực tiếp") {
                LabeledContent("Trạng thái", value: connection.state.localizedDescription)

                if connection.state.isReady {
                    Button("Ngắt kết nối", role: .destructive) { connection.disconnect() }
                    Button("Quên thiết bị", role: .destructive) { connection.forgetDevice() }
                } else {
                    if connection.hasSavedDevice {
                        Button("Kết nối lại Band đã lưu") {
                            connection.reconnectSavedDevice()
                        }
                    }
                    Button(connection.state == .scanning ? "Đang tìm…" : "Tìm Mi Band 8") {
                        connection.startScan()
                    }
                    .disabled(connection.state == .scanning)
                    Text("Đóng hẳn Mi Fitness trước, sau đó mới bấm kết nối. MiMaps không còn tự kết nối Band khi khởi động.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            if !connection.discoveredDevices.isEmpty {
                Section("Thiết bị tìm thấy") {
                    ForEach(connection.discoveredDevices) { device in
                        Button {
                            connection.connect(to: device)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .foregroundStyle(.primary)
                                    Text(device.id.uuidString)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(device.rssi) dBm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !connection.characteristics.isEmpty {
                Section("GATT đã phát hiện") {
                    ForEach(Array(connection.characteristics.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.characteristicUUID)
                                .font(.caption.monospaced())
                            Text("Service \(item.serviceUUID)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                            Text(item.properties.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Xác thực thiết bị") {
                LabeledContent("Trạng thái", value: connection.authenticationState.localizedDescription)
                if let fingerprint = connection.savedKeyFingerprint {
                    LabeledContent("Khóa đã lưu", value: fingerprint)
                    if connection.state.isReady {
                        Button(connection.authenticationState == .authenticated ? "Đã xác thực" : "Xác thực trực tiếp") {
                            connection.authenticate()
                        }
                        .disabled(
                            connection.authenticationState.isInProgress
                                || connection.authenticationState == .authenticated
                        )
                    }
                    Button("Xóa khóa", role: .destructive) {
                        do {
                            try connection.deleteAuthenticationKey()
                            authenticationKey = ""
                            keyError = nil
                        } catch {
                            keyError = error.localizedDescription
                        }
                    }
                } else {
                    SecureField("32 ký tự hex", text: $authenticationKey)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Lưu vào Keychain") {
                        do {
                            try connection.saveAuthenticationKey(authenticationKey)
                            authenticationKey = ""
                            keyError = nil
                        } catch {
                            keyError = error.localizedDescription
                        }
                    }
                    .disabled(MiBandAuthenticationKey.normalize(authenticationKey) == nil)
                }

                if let keyError {
                    Text(keyError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Text("Khóa 16 byte được lấy từ dữ liệu ghép đôi Mi Fitness, chỉ lưu cục bộ trong Keychain và không xuất hiện trong báo cáo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Trước khi xác thực, hãy đóng hẳn Mi Fitness khỏi màn hình đa nhiệm. Không hủy ghép đôi và không reset vòng.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if connection.authenticationState == .authenticated {
                Section("Thông báo trực tiếp") {
                    LabeledContent(
                        "Trạng thái",
                        value: connection.directNotificationState.localizedDescription
                    )
                    Button("Gửi thử: rẽ trái sau 100 m") {
                        connection.sendTestNavigationNotification()
                    }
                    if connection.decryptedPacketCount > 0 || connection.sentCommandCount > 0 {
                        LabeledContent(
                            "Gói phiên đã giải mã",
                            value: "\(connection.decryptedPacketCount)"
                        )
                        LabeledContent(
                            "Lệnh mã hóa đã gửi",
                            value: "\(connection.sentCommandCount)"
                        )
                    }
                    Text("Lệnh được mã hóa và gửi thẳng từ MiMaps qua Bluetooth; Mi Fitness không tham gia. Hãy kiểm tra cả màn hình Band và trạng thái ACK sau khi bấm thử.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if connection.state.isReady {
                Section("Thu dữ liệu giao thức") {
                    if connection.isCapturingPackets {
                        Button("Dừng thu dữ liệu", role: .destructive) {
                            connection.stopPacketCapture()
                        }
                    } else {
                        Button("Bắt đầu thu dữ liệu") {
                            connection.startPacketCapture()
                        }
                    }
                    LabeledContent("Gói đã nhận", value: "\(connection.capturedPackets.count)")
                    Text("Chế độ này lưu bản xem trước gói FE95/FDAB để chẩn đoán. MiMaps hiện có thể ACK, giải mã phiên và gửi thử thông báo trực tiếp; chưa cài ứng dụng hay firmware lên vòng.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Chẩn đoán") {
                ShareLink(item: connection.diagnosticsReport()) {
                    Label("Chia sẻ báo cáo Band Lab", systemImage: "square.and.arrow.up")
                }
                Text("Band Lab lưu khóa ghép đôi trong Keychain, xác thực và gửi lệnh thông báo trực tiếp tới Band 8. Việc cài companion riêng vẫn được khóa cho tới khi kênh gửi nhận mã hóa vượt qua kiểm thử thực tế.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Mi Band 8")
        .onDisappear {
            connection.stopScan()
            connection.stopPacketCapture()
        }
    }
}
