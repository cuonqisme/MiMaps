import SwiftUI

struct BandConnectionView: View {
    @ObservedObject private var connection: MiBandDirectConnection

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

            Section("Chẩn đoán") {
                ShareLink(item: connection.diagnosticsReport()) {
                    Label("Chia sẻ báo cáo Band Lab", systemImage: "square.and.arrow.up")
                }
                Text("Mốc này chỉ đọc danh sách GATT, chưa gửi lệnh cấu hình hoặc firmware. MiMaps sẽ chỉ bật ghi dữ liệu sau khi nhận diện và xác thực đúng giao thức của thiết bị.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Mi Band 8")
        .onDisappear { connection.stopScan() }
    }
}

