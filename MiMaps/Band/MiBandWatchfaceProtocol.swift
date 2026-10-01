import Foundation

enum MiBandWatchfacePackageError: LocalizedError, Equatable {
    case tooSmall
    case invalidMagic
    case missingNumericIdentifier

    var errorDescription: String? {
        switch self {
        case .tooSmall:
            "Gói mặt đồng hồ quá ngắn."
        case .invalidMagic:
            "Tệp không phải mặt đồng hồ Xiaomi 5A A5."
        case .missingNumericIdentifier:
            "Không tìm thấy ID số hợp lệ trong gói mặt đồng hồ."
        }
    }
}

enum MiBandWatchfaceProtocolError: LocalizedError, Equatable {
    case malformedProtobuf

    var errorDescription: String? {
        "Phản hồi cài mặt đồng hồ không hợp lệ."
    }
}

struct MiBandWatchfacePackage: Equatable, Sendable {
    static let identifierOffset = 0x28
    static let minimumHeaderLength = 0x80

    let identifier: String
    let bytes: Data

    init(bytes: Data) throws {
        guard bytes.count >= Self.minimumHeaderLength else {
            throw MiBandWatchfacePackageError.tooSmall
        }
        guard bytes[bytes.startIndex] == 0x5A,
              bytes[bytes.startIndex + 1] == 0xA5 else {
            throw MiBandWatchfacePackageError.invalidMagic
        }

        let identifierBytes = bytes
            .dropFirst(Self.identifierOffset)
            .prefix { $0 != 0 }
        guard !identifierBytes.isEmpty,
              identifierBytes.allSatisfy({ (0x30...0x39).contains($0) }),
              let identifier = String(data: Data(identifierBytes), encoding: .ascii) else {
            throw MiBandWatchfacePackageError.missingNumericIdentifier
        }

        self.identifier = identifier
        self.bytes = bytes
    }
}

/// Xiaomi keeps watchface installation separate from the bulk type-16 upload:
/// type 4/subtype 4 opens an install transaction and type 4/subtype 1 activates
/// the face after the upload succeeds.
enum MiBandWatchfaceProtocol {
    static let commandType: UInt64 = 4
    static let installSubtype: UInt64 = 4
    static let setSubtype: UInt64 = 1
    static let uploadType: UInt8 = 16

    static func makeInstallStartCommand(
        identifier: String,
        byteCount: Int
    ) -> Data {
        let start = fieldString(1, identifier)
            + fieldVarint(2, UInt64(byteCount))
        let watchface = fieldMessage(6, start)
        return fieldVarint(1, commandType)
            + fieldVarint(2, installSubtype)
            + fieldMessage(6, watchface)
    }

    static func makeSetCommand(identifier: String) -> Data {
        let watchface = fieldString(2, identifier)
        return fieldVarint(1, commandType)
            + fieldVarint(2, setSubtype)
            + fieldMessage(6, watchface)
    }

    static func installStatus(from command: Data) throws -> UInt64? {
        let root = try fields(command)
        guard root.varint(1) == commandType,
              root.varint(2) == installSubtype else { return nil }
        guard let watchfaceBytes = root.bytes(6) else {
            throw MiBandWatchfaceProtocolError.malformedProtobuf
        }
        return try fields(watchfaceBytes).varint(5)
    }

    private static func fieldVarint(_ number: UInt64, _ value: UInt64) -> Data {
        encodeVarint((number << 3) | 0) + encodeVarint(value)
    }

    private static func fieldString(_ number: UInt64, _ value: String) -> Data {
        fieldMessage(number, Data(value.utf8))
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
    }

    private static func fields(_ data: Data) throws -> FieldList {
        let bytes = [UInt8](data)
        var index = 0
        var output: [Field] = []
        while index < bytes.count {
            let key = try decodeVarint(bytes, index: &index)
            let fieldNumber = key >> 3
            switch key & 0x07 {
            case 0:
                output.append(Field(
                    number: fieldNumber,
                    varint: try decodeVarint(bytes, index: &index),
                    bytes: nil
                ))
            case 2:
                let count = Int(try decodeVarint(bytes, index: &index))
                guard count >= 0, index + count <= bytes.count else {
                    throw MiBandWatchfaceProtocolError.malformedProtobuf
                }
                output.append(Field(
                    number: fieldNumber,
                    varint: nil,
                    bytes: Data(bytes[index..<(index + count)])
                ))
                index += count
            default:
                throw MiBandWatchfaceProtocolError.malformedProtobuf
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
        throw MiBandWatchfaceProtocolError.malformedProtobuf
    }
}
