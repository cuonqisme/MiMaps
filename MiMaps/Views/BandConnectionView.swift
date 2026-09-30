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
                    Button(connection.state == .scanning ? "Đang tìm…" : "Tìm Mi Band 8") {
                        connection.startScan()
                    }
                    .disabled(connection.state == .scanning)
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
                    Text("Chế độ này lưu bản xem trước gói FE95/FDAB để chẩn đoán. Nút xác thực chỉ thực hiện bắt tay bảo mật, chưa cài ứng dụng hay firmware lên vòng.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Chẩn đoán") {
                ShareLink(item: connection.diagnosticsReport()) {
                    Label("Chia sẻ báo cáo Band Lab", systemImage: "square.and.arrow.up")
                }
                Text("Band Lab lưu khóa ghép đôi trong Keychain, thu gói chẩn đoán và có thể xác thực trực tiếp với Band 8. Việc cài companion và gửi giao diện điều hướng vẫn được khóa cho tới khi bước xác thực này vượt qua kiểm thử thực tế.")
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
