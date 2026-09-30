import CryptoSwift
import Foundation

enum MiBandSessionProtocolError: LocalizedError, Equatable {
    case invalidFrame
    case invalidSessionKeys
    case decryptionFailed
    case encryptionFailed
    case counterExhausted

    var errorDescription: String? {
        switch self {
        case .invalidFrame:
            "Khung phiên từ Mi Band không hợp lệ."
        case .invalidSessionKeys:
            "Khóa phiên Mi Band không hợp lệ."
        case .decryptionFailed:
            "Không thể giải mã dữ liệu phiên từ Mi Band."
        case .encryptionFailed:
            "Không thể mã hóa lệnh gửi tới Mi Band."
        case .counterExhausted:
            "Bộ đếm phiên Mi Band đã hết; cần xác thực lại."
        }
    }
}

struct MiBandCommandEnvelope: Equatable, Sendable {
    let type: UInt64?
    let subtype: UInt64?
}

enum MiBandSessionProtocol {
    static let acknowledgement = Data([0x00, 0x00, 0x03, 0x00])

    static func isEncryptedSingleFrame(_ frame: Data) -> Bool {
        guard frame.count >= 8 else { return false }
        return frame.starts(with: [0x00, 0x00, 0x02, 0x01])
    }

    static func acknowledgementResult(from frame: Data) -> UInt8? {
        guard frame.count == 4,
              frame.starts(with: [0x00, 0x00, 0x03]) else { return nil }
        return frame.last
    }

    static func decryptIncomingSingleFrame(
        _ frame: Data,
        sessionKeys: MiBandSessionKeys
    ) throws -> Data {
        guard isEncryptedSingleFrame(frame) else {
            throw MiBandSessionProtocolError.invalidFrame
        }
        return try decryptCCM(
            Data(frame.dropFirst(4)),
            key: sessionKeys.decryptionKey,
            noncePrefix: sessionKeys.decryptionNonce,
            counter: 0
        )
    }

    static func makeEncryptedSingleFrame(
        command: Data,
        sessionKeys: MiBandSessionKeys,
        counter: UInt16
    ) throws -> Data {
        guard counter > 0 else {
            throw MiBandSessionProtocolError.counterExhausted
        }
        let encrypted = try encryptCCM(
            command,
            key: sessionKeys.encryptionKey,
            noncePrefix: sessionKeys.encryptionNonce,
            counter: UInt32(counter)
        )
        var littleEndianCounter = counter.littleEndian
        var frame = Data([0x00, 0x00, 0x02, 0x01])
        withUnsafeBytes(of: &littleEndianCounter) { frame.append(contentsOf: $0) }
        frame.append(encrypted)
        return frame
    }

    /// Encrypts a payload for Xiaomi's auxiliary FE95 channels. Those channels
    /// intentionally use nonce counter zero and apply their own GATT framing.
    static func encryptAuxiliaryPayload(
        _ payload: Data,
        sessionKeys: MiBandSessionKeys
    ) throws -> Data {
        try encryptCCM(
            payload,
            key: sessionKeys.encryptionKey,
            noncePrefix: sessionKeys.encryptionNonce,
            counter: 0
        )
    }

    static func commandEnvelope(from command: Data) -> MiBandCommandEnvelope {
        var offset = 0
        var type: UInt64?
        var subtype: UInt64?

        while offset < command.count {
            guard let key = readVarint(command, offset: &offset) else { break }
            let field = key >> 3
            let wire = key & 0x07
            switch wire {
            case 0:
                guard let value = readVarint(command, offset: &offset) else {
                    return MiBandCommandEnvelope(type: type, subtype: subtype)
                }
                if field == 1 { type = value }
                if field == 2 { subtype = value }
            case 1:
                guard offset <= command.count - 8 else {
                    return MiBandCommandEnvelope(type: type, subtype: subtype)
                }
                offset += 8
            case 2:
                guard let length = readVarint(command, offset: &offset),
                      length <= UInt64(command.count - offset) else {
                    return MiBandCommandEnvelope(type: type, subtype: subtype)
                }
                offset += Int(length)
            case 5:
                guard offset <= command.count - 4 else {
                    return MiBandCommandEnvelope(type: type, subtype: subtype)
                }
                offset += 4
            default:
                return MiBandCommandEnvelope(type: type, subtype: subtype)
            }
        }
        return MiBandCommandEnvelope(type: type, subtype: subtype)
    }

    private static func nonce(prefix: Data, counter: UInt32) throws -> Data {
        guard prefix.count == 4 else {
            throw MiBandSessionProtocolError.invalidSessionKeys
        }
        var value = prefix + Data(repeating: 0, count: 4)
        var littleEndianCounter = counter.littleEndian
        withUnsafeBytes(of: &littleEndianCounter) { value.append(contentsOf: $0) }
        return value
    }

    private static func encryptCCM(
        _ plaintext: Data,
        key: Data,
        noncePrefix: Data,
        counter: UInt32
    ) throws -> Data {
        guard key.count == 16 else {
            throw MiBandSessionProtocolError.invalidSessionKeys
        }
        do {
            let initializationVector = try nonce(prefix: noncePrefix, counter: counter)
            let mode = CCM(
                iv: Array(initializationVector),
                tagLength: 4,
                messageLength: plaintext.count
            )
            let aes = try AES(key: Array(key), blockMode: mode, padding: .noPadding)
            return Data(try aes.encrypt(Array(plaintext)))
        } catch let error as MiBandSessionProtocolError {
            throw error
        } catch {
            throw MiBandSessionProtocolError.encryptionFailed
        }
    }

    private static func decryptCCM(
        _ ciphertextAndTag: Data,
        key: Data,
        noncePrefix: Data,
        counter: UInt32
    ) throws -> Data {
        guard key.count == 16, ciphertextAndTag.count >= 4 else {
            throw MiBandSessionProtocolError.invalidSessionKeys
        }
        do {
            let initializationVector = try nonce(prefix: noncePrefix, counter: counter)
            let mode = CCM(
                iv: Array(initializationVector),
                tagLength: 4,
                messageLength: ciphertextAndTag.count - 4
            )
            let aes = try AES(key: Array(key), blockMode: mode, padding: .noPadding)
            return Data(try aes.decrypt(Array(ciphertextAndTag)))
        } catch let error as MiBandSessionProtocolError {
            throw error
        } catch {
            throw MiBandSessionProtocolError.decryptionFailed
        }
    }

    private static func readVarint(_ data: Data, offset: inout Int) -> UInt64? {
        var value: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard offset < data.count else { return nil }
            let byte = data[offset]
            offset += 1
            if shift == 63, byte > 1 { return nil }
            value |= UInt64(byte & 0x7F) << UInt64(shift)
            if byte & 0x80 == 0 { return value }
        }
        return nil
    }
}
