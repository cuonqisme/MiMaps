import Foundation

struct MiBandNotificationIconRequest: Equatable, Sendable {
    let status: UInt64
    let pixelFormat: UInt64
    let size: UInt64
}

enum MiBandNotificationIconProtocolError: LocalizedError, Equatable {
    case malformedProtobuf
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .malformedProtobuf: "Gói yêu cầu icon từ Band không hợp lệ."
        case .invalidUTF8: "Tên package trong yêu cầu icon không hợp lệ."
        }
    }
}

enum MiBandNotificationIconProtocol {
    private static let notificationType: UInt64 = 7
    private static let iconRequestSubtype: UInt64 = 15
    private static let iconQuerySubtype: UInt64 = 16

    static func packageQuery(from command: Data) throws -> String? {
        let root = try fields(in: command)
        guard root.varint(1) == notificationType,
              root.varint(2) == iconQuerySubtype else { return nil }
        guard let notification = root.bytes(9),
              let packageMessage = try fields(in: notification).bytes(16),
              let packageData = try fields(in: packageMessage).bytes(1) else {
            throw MiBandNotificationIconProtocolError.malformedProtobuf
        }
        guard let package = String(data: packageData, encoding: .utf8) else {
            throw MiBandNotificationIconProtocolError.invalidUTF8
        }
        return package
    }

    static func makePackageReply(package: String) -> Data {
        let packageMessage = fieldMessage(1, Data(package.utf8))
        let notification = fieldMessage(14, packageMessage)
        return fieldVarint(1, notificationType)
            + fieldVarint(2, iconRequestSubtype)
            + fieldMessage(9, notification)
    }

    static func iconRequest(from command: Data) throws -> MiBandNotificationIconRequest? {
        let root = try fields(in: command)
        guard root.varint(1) == notificationType,
              root.varint(2) == iconRequestSubtype else { return nil }
        guard let notification = root.bytes(9),
              let request = try fields(in: notification).bytes(15) else {
            throw MiBandNotificationIconProtocolError.malformedProtobuf
        }
        let requestFields = try fields(in: request)
        guard let status = requestFields.varint(1),
              let pixelFormat = requestFields.varint(2),
              let size = requestFields.varint(3) else {
            throw MiBandNotificationIconProtocolError.malformedProtobuf
        }
        return MiBandNotificationIconRequest(
            status: status,
            pixelFormat: pixelFormat,
            size: size
        )
    }

    private struct Field {
        let number: UInt64
        let varint: UInt64?
        let bytes: Data?
    }

    private struct FieldList {
        let values: [Field]

        func varint(_ number: UInt64) -> UInt64? {
            values.first { $0.number == number && $0.varint != nil }?.varint
        }

        func bytes(_ number: UInt64) -> Data? {
            values.first { $0.number == number && $0.bytes != nil }?.bytes
        }
    }

    private static func fields(in data: Data) throws -> FieldList {
        let bytes = [UInt8](data)
        var index = 0
        var output: [Field] = []
        while index < bytes.count {
            let key = try decodeVarint(bytes, index: &index)
            let number = key >> 3
            switch key & 0x07 {
            case 0:
                output.append(Field(
                    number: number,
                    varint: try decodeVarint(bytes, index: &index),
                    bytes: nil
                ))
            case 2:
                let length = try decodeVarint(bytes, index: &index)
                guard length <= UInt64(bytes.count - index) else {
                    throw MiBandNotificationIconProtocolError.malformedProtobuf
                }
                let end = index + Int(length)
                output.append(Field(
                    number: number,
                    varint: nil,
                    bytes: Data(bytes[index..<end])
                ))
                index = end
            default:
                throw MiBandNotificationIconProtocolError.malformedProtobuf
            }
        }
        return FieldList(values: output)
    }

    private static func decodeVarint(_ bytes: [UInt8], index: inout Int) throws -> UInt64 {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while index < bytes.count, shift < 64 {
            let byte = bytes[index]
            index += 1
            value |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return value }
            shift += 7
        }
        throw MiBandNotificationIconProtocolError.malformedProtobuf
    }

    private static func fieldVarint(_ number: UInt64, _ value: UInt64) -> Data {
        encodeVarint((number << 3) | 0) + encodeVarint(value)
    }

    private static func fieldMessage(_ number: UInt64, _ value: Data) -> Data {
        encodeVarint((number << 3) | 2) + encodeVarint(UInt64(value.count)) + value
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
}
