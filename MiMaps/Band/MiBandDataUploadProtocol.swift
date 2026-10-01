import CryptoKit
import Foundation

enum MiBandIconUploadFollowUp: Equatable, Sendable {
    case deliverPendingNotification
    case restartForUpdatedManeuver
    case cacheAdditionalSize

    static func resolve(
        pendingManeuver: NavigationManeuver?,
        completedManeuver: NavigationManeuver?
    ) -> Self {
        guard let pendingManeuver else { return .cacheAdditionalSize }
        return pendingManeuver == completedManeuver
            ? .deliverPendingNotification
            : .restartForUpdatedManeuver
    }
}

struct MiBandDataUploadAcknowledgement: Equatable, Sendable {
    let status: UInt64
    let resumePosition: UInt64
    let chunkSize: Int
}

enum MiBandDataUploadProtocolError: LocalizedError, Equatable {
    case malformedProtobuf
    case rejected(status: UInt64, resumePosition: UInt64)
    case invalidChunkSize

    var errorDescription: String? {
        switch self {
        case .malformedProtobuf:
            "Phản hồi upload từ Mi Band không hợp lệ."
        case let .rejected(status, resumePosition):
            "Mi Band từ chối upload (status=\(status), resume=\(resumePosition))."
        case .invalidChunkSize:
            "Kích thước khối upload do Mi Band trả về không hợp lệ."
        }
    }
}

/// Builds the Xiaomi data-upload commands used for notification icons and
/// watchface packages. The binary stream is intentionally kept independent
/// from CoreBluetooth so its framing can be verified with unit tests.
enum MiBandDataUploadProtocol {
    static let commandType: UInt64 = 22
    static let uploadSubtype: UInt64 = 0
    static let notificationIconType: UInt8 = 50
    static let defaultChunkSize = 2_048

    static func makeUploadRequest(type: UInt8, bytes: Data) -> Data {
        let request = fieldVarint(1, UInt64(type))
            + fieldBytes(2, md5(bytes))
            + fieldVarint(3, UInt64(bytes.count))
        let upload = fieldMessage(1, request)
        return fieldVarint(1, commandType)
            + fieldVarint(2, uploadSubtype)
            + fieldMessage(24, upload)
    }

    static func acknowledgement(from command: Data) throws -> MiBandDataUploadAcknowledgement? {
        let commandFields = try fields(command)
        guard commandFields.varint(1) == commandType,
              commandFields.varint(2) == uploadSubtype else { return nil }
        guard let uploadData = commandFields.bytes(24),
              let acknowledgementData = try fields(uploadData).bytes(2) else {
            throw MiBandDataUploadProtocolError.malformedProtobuf
        }
        let acknowledgement = try fields(acknowledgementData)
        let status = acknowledgement.varint(2) ?? 0
        let resumePosition = acknowledgement.varint(4) ?? 0
        guard status == 0, resumePosition == 0 else {
            throw MiBandDataUploadProtocolError.rejected(
                status: status,
                resumePosition: resumePosition
            )
        }
        let chunkSize = Int(acknowledgement.varint(5) ?? UInt64(defaultChunkSize))
        guard chunkSize > 8, chunkSize <= Int(UInt16.max) else {
            throw MiBandDataUploadProtocolError.invalidChunkSize
        }
        return MiBandDataUploadAcknowledgement(
            status: status,
            resumePosition: resumePosition,
            chunkSize: chunkSize
        )
    }

    static func uploadParts(type: UInt8, bytes: Data, chunkSize: Int) throws -> [Data] {
        guard chunkSize > 8, chunkSize <= Int(UInt16.max) else {
            throw MiBandDataUploadProtocolError.invalidChunkSize
        }

        var payload = Data([0, type])
        payload.append(md5(bytes))
        payload.append(littleEndian: UInt32(bytes.count))
        payload.append(bytes)
        payload.append(littleEndian: crc32(payload))

        let partPayloadSize = chunkSize - 4
        let totalParts = Int(ceil(Double(payload.count) / Double(partPayloadSize)))
        guard totalParts > 0, totalParts <= Int(UInt16.max) else {
            throw MiBandDataUploadProtocolError.invalidChunkSize
        }

        return (0..<totalParts).map { index in
            let start = index * partPayloadSize
            let end = min(start + partPayloadSize, payload.count)
            var part = Data()
            part.append(littleEndian: UInt16(totalParts))
            part.append(littleEndian: UInt16(index + 1))
            part.append(payload[start..<end])
            return part
        }
    }

    /// Xiaomi's chunk channel asks the sender to retransmit missing BLE frames
    /// with `00 00 01 05`, followed by little-endian, one-based frame indexes.
    /// Returning nil distinguishes this packet from the ordinary start/end ACKs.
    static func missingChunkIndexes(from data: Data) -> [Int]? {
        let bytes = [UInt8](data)
        guard bytes.count >= 4,
              bytes[0] == 0,
              bytes[1] == 0,
              bytes[2] == 1,
              bytes[3] == 5,
              (bytes.count - 4).isMultiple(of: 2) else { return nil }

        return stride(from: 4, to: bytes.count, by: 2).map { offset in
            Int(UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8))
        }
    }

    static func md5(_ bytes: Data) -> Data {
        Data(Insecure.MD5.hash(data: bytes))
    }

    static func crc32(_ bytes: Data) -> UInt32 {
        var value: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            value ^= UInt32(byte)
            for _ in 0..<8 {
                value = (value & 1) == 1
                    ? (value >> 1) ^ 0xEDB8_8320
                    : value >> 1
            }
        }
        return value ^ 0xFFFF_FFFF
    }

    private struct Field: Sendable {
        let number: UInt64
        let varint: UInt64?
        let bytes: Data?
    }

    private struct FieldList: Sendable {
        let values: [Field]

        func varint(_ number: UInt64) -> UInt64? {
            values.first { $0.number == number }?.varint
        }

        func bytes(_ number: UInt64) -> Data? {
            values.first { $0.number == number }?.bytes
        }
    }

    private static func fields(_ data: Data) throws -> FieldList {
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
                    throw MiBandDataUploadProtocolError.malformedProtobuf
                }
                let end = index + Int(length)
                output.append(Field(
                    number: number,
                    varint: nil,
                    bytes: Data(bytes[index..<end])
                ))
                index = end
            default:
                throw MiBandDataUploadProtocolError.malformedProtobuf
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
        throw MiBandDataUploadProtocolError.malformedProtobuf
    }

    private static func fieldVarint(_ number: UInt64, _ value: UInt64) -> Data {
        encodeVarint(number << 3) + encodeVarint(value)
    }

    private static func fieldBytes(_ number: UInt64, _ value: Data) -> Data {
        fieldMessage(number, value)
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

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { append(contentsOf: $0) }
    }
}
