import Foundation

enum MiBandSystemProtocolError: LocalizedError, Equatable {
    case malformedProtobuf

    var errorDescription: String? {
        switch self {
        case .malformedProtobuf:
            "Phản hồi thông tin hệ thống từ Mi Band không hợp lệ."
        }
    }
}

/// Commands and small protobuf decoders for Xiaomi's type-2 system service.
/// Mi Band 8 exposes standard GATT device/battery characteristics, but some
/// firmware returns the Cordio stack revision and a placeholder zero there.
/// The authenticated Xiaomi service is the authoritative source.
enum MiBandSystemProtocol {
    static let commandType: UInt64 = 2
    static let batterySubtype: UInt64 = 1
    static let deviceInfoSubtype: UInt64 = 2
    static let basicDeviceStateSubtype: UInt64 = 78

    struct DeviceInformation: Equatable, Sendable {
        let firmware: String
        let model: String?
        let serialNumber: String?
    }

    static func makeBatteryCommand() -> Data {
        makeCommand(subtype: batterySubtype)
    }

    static func makeDeviceInfoCommand() -> Data {
        makeCommand(subtype: deviceInfoSubtype)
    }

    static func makeBasicDeviceStateCommand() -> Data {
        makeCommand(subtype: basicDeviceStateSubtype)
    }

    static func batteryLevel(from command: Data) throws -> Int? {
        let root = try fields(command)
        guard root.varint(1) == commandType,
              let subtype = root.varint(2) else { return nil }
        guard let systemData = root.bytes(4) else {
            throw MiBandSystemProtocolError.malformedProtobuf
        }
        let system = try fields(systemData)

        let rawLevel: UInt64?
        switch subtype {
        case batterySubtype:
            guard let powerData = system.bytes(2),
                  let batteryData = try fields(powerData).bytes(1) else {
                throw MiBandSystemProtocolError.malformedProtobuf
            }
            rawLevel = try fields(batteryData).varint(1)
        case basicDeviceStateSubtype:
            guard let stateData = system.bytes(48) else {
                throw MiBandSystemProtocolError.malformedProtobuf
            }
            rawLevel = try fields(stateData).varint(2)
        default:
            return nil
        }

        guard let rawLevel, rawLevel <= 100 else {
            throw MiBandSystemProtocolError.malformedProtobuf
        }
        return Int(rawLevel)
    }

    static func deviceInformation(from command: Data) throws -> DeviceInformation? {
        let root = try fields(command)
        guard root.varint(1) == commandType,
              root.varint(2) == deviceInfoSubtype else { return nil }
        guard let systemData = root.bytes(4),
              let infoData = try fields(systemData).bytes(3) else {
            throw MiBandSystemProtocolError.malformedProtobuf
        }
        let info = try fields(infoData)
        guard let firmware = info.string(2), !firmware.isEmpty else {
            throw MiBandSystemProtocolError.malformedProtobuf
        }
        return DeviceInformation(
            firmware: firmware,
            model: info.string(4),
            serialNumber: info.string(1)
        )
    }

    private static func makeCommand(subtype: UInt64) -> Data {
        fieldVarint(1, commandType) + fieldVarint(2, subtype)
    }

    private static func fieldVarint(_ number: UInt64, _ value: UInt64) -> Data {
        encodeVarint(number << 3) + encodeVarint(value)
    }

    private static func encodeVarint(_ value: UInt64) -> Data {
        var remaining = value
        var output = Data()
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            output.append(byte)
        } while remaining != 0
        return output
    }

    private struct Field: Sendable {
        let number: UInt64
        let varint: UInt64?
        let bytes: Data?
    }

    private struct FieldList: Sendable {
        let values: [Field]

        func varint(_ number: UInt64) -> UInt64? {
            values.first { $0.number == number && $0.varint != nil }?.varint
        }

        func bytes(_ number: UInt64) -> Data? {
            values.first { $0.number == number && $0.bytes != nil }?.bytes
        }

        func string(_ number: UInt64) -> String? {
            bytes(number).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    private static func fields(_ data: Data) throws -> FieldList {
        let bytes = [UInt8](data)
        var index = 0
        var output: [Field] = []
        while index < bytes.count {
            let key = try decodeVarint(bytes, index: &index)
            let fieldNumber = key >> 3
            guard fieldNumber > 0 else {
                throw MiBandSystemProtocolError.malformedProtobuf
            }
            switch key & 0x07 {
            case 0:
                output.append(Field(
                    number: fieldNumber,
                    varint: try decodeVarint(bytes, index: &index),
                    bytes: nil
                ))
            case 2:
                let count = try decodeVarint(bytes, index: &index)
                guard count <= UInt64(bytes.count - index) else {
                    throw MiBandSystemProtocolError.malformedProtobuf
                }
                let end = index + Int(count)
                output.append(Field(
                    number: fieldNumber,
                    varint: nil,
                    bytes: Data(bytes[index..<end])
                ))
                index = end
            default:
                throw MiBandSystemProtocolError.malformedProtobuf
            }
        }
        return FieldList(values: output)
    }

    private static func decodeVarint(
        _ bytes: [UInt8],
        index: inout Int
    ) throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < bytes.count, shift < 64 {
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        throw MiBandSystemProtocolError.malformedProtobuf
    }
}
