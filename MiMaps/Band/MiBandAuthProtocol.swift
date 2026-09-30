import CryptoKit
import CryptoSwift
import Foundation

enum MiBandAuthProtocolError: LocalizedError, Equatable {
    case invalidKey
    case invalidNonce
    case malformedResponse
    case unexpectedResponse
    case watchVerificationFailed
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidKey: "Khóa xác thực không hợp lệ."
        case .invalidNonce: "Nonce xác thực không hợp lệ."
        case .malformedResponse: "Phản hồi xác thực của vòng bị lỗi."
        case .unexpectedResponse: "Vòng trả về phản hồi không đúng bước xác thực."
        case .watchVerificationFailed: "Khóa không khớp với vòng; đã dừng trước khi gửi cấu hình."
        case .encryptionFailed: "Không thể mã hóa dữ liệu xác thực."
        }
    }
}

struct MiBandSessionKeys: Equatable, Sendable {
    let decryptionKey: Data
    let encryptionKey: Data
    let decryptionNonce: Data
    let encryptionNonce: Data
}

struct MiBandWatchChallenge: Equatable, Sendable {
    let nonce: Data
    let hmac: Data
}

enum MiBandAuthProtocol {
    static let commandType: UInt64 = 1
    static let nonceSubtype: UInt64 = 26
    static let authSubtype: UInt64 = 27

    static func keyData(from normalizedKey: String) throws -> Data {
        guard let normalized = MiBandAuthenticationKey.normalize(normalizedKey) else {
            throw MiBandAuthProtocolError.invalidKey
        }
        var bytes = Data(capacity: MiBandAuthenticationKey.byteCount)
        var index = normalized.startIndex
        while index < normalized.endIndex {
            let next = normalized.index(index, offsetBy: 2)
            guard let byte = UInt8(normalized[index..<next], radix: 16) else {
                throw MiBandAuthProtocolError.invalidKey
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    static func makePhoneNonceCommand(phoneNonce: Data) throws -> Data {
        guard phoneNonce.count == 16 else { throw MiBandAuthProtocolError.invalidNonce }
        let phoneNonceMessage = fieldBytes(1, phoneNonce)
        let authMessage = fieldMessage(30, phoneNonceMessage)
        return fieldVarint(1, commandType)
            + fieldVarint(2, nonceSubtype)
            + fieldMessage(3, authMessage)
    }

    static func parseWatchChallenge(command: Data) throws -> MiBandWatchChallenge {
        let root = try ProtobufFields(command)
        guard root.varint(1) == commandType,
              root.varint(2) == nonceSubtype,
              let authData = root.bytes(3) else {
            throw MiBandAuthProtocolError.unexpectedResponse
        }
        let auth = try ProtobufFields(authData)
        guard let watchNonceData = auth.bytes(31) else {
            throw MiBandAuthProtocolError.malformedResponse
        }
        let watchNonce = try ProtobufFields(watchNonceData)
        guard let nonce = watchNonce.bytes(1), nonce.count == 16,
              let hmac = watchNonce.bytes(2), hmac.count == 32 else {
            throw MiBandAuthProtocolError.malformedResponse
        }
        return MiBandWatchChallenge(nonce: nonce, hmac: hmac)
    }

    static func deriveSessionKeys(secretKey: Data, phoneNonce: Data, watchNonce: Data) throws -> MiBandSessionKeys {
        guard secretKey.count == 16 else { throw MiBandAuthProtocolError.invalidKey }
        guard phoneNonce.count == 16, watchNonce.count == 16 else {
            throw MiBandAuthProtocolError.invalidNonce
        }

        let pseudorandomKey = hmac(key: phoneNonce + watchNonce, data: secretKey)
        let info = Data("miwear-auth".utf8)
        var output = Data()
        var previous = Data()
        for counter: UInt8 in 1...2 {
            previous = hmac(key: pseudorandomKey, data: previous + info + Data([counter]))
            output.append(previous)
        }

        return MiBandSessionKeys(
            decryptionKey: output.subdata(in: 0..<16),
            encryptionKey: output.subdata(in: 16..<32),
            decryptionNonce: output.subdata(in: 32..<36),
            encryptionNonce: output.subdata(in: 36..<40)
        )
    }

    static func verifyWatch(
        challenge: MiBandWatchChallenge,
        phoneNonce: Data,
        sessionKeys: MiBandSessionKeys
    ) -> Bool {
        let expected = hmac(
            key: sessionKeys.decryptionKey,
            data: challenge.nonce + phoneNonce
        )
        return constantTimeEqual(expected, challenge.hmac)
    }

    static func makeAuthenticationCommand(
        phoneNonce: Data,
        watchNonce: Data,
        sessionKeys: MiBandSessionKeys,
        phoneName: String,
        region: String,
        apiLevel: Float = 34
    ) throws -> Data {
        guard phoneNonce.count == 16, watchNonce.count == 16 else {
            throw MiBandAuthProtocolError.invalidNonce
        }

        let proof = hmac(key: sessionKeys.encryptionKey, data: phoneNonce + watchNonce)
        let normalizedRegion = String(region.uppercased().prefix(2))
        let deviceInfo = fieldVarint(1, 0)
            + fieldFloat(2, apiLevel)
            + fieldString(3, phoneName)
            + fieldVarint(4, 224)
            + fieldString(5, normalizedRegion.isEmpty ? "VN" : normalizedRegion)
        let encryptedDeviceInfo = try encryptCCM(
            deviceInfo,
            key: sessionKeys.encryptionKey,
            noncePrefix: sessionKeys.encryptionNonce,
            counter: 0
        )
        let step3 = fieldBytes(1, proof) + fieldBytes(2, encryptedDeviceInfo)
        let auth = fieldMessage(32, step3)
        return fieldVarint(1, commandType)
            + fieldVarint(2, authSubtype)
            + fieldMessage(3, auth)
    }

    static func isAuthenticationSuccess(command: Data) throws -> Bool {
        let root = try ProtobufFields(command)
        guard root.varint(1) == commandType,
              root.varint(2) == authSubtype else {
            throw MiBandAuthProtocolError.unexpectedResponse
        }
        // Mi Band 8 uses subtype 27 itself as the success signal. Some firmware
        // also includes Auth.status, but its default protobuf value is not a NACK.
        return true
    }

    static func plaintextFrame(_ command: Data) -> Data {
        Data([0x00, 0x00, 0x02, 0x02]) + command
    }

    static func plaintextPayload(from frame: Data) -> Data? {
        guard frame.count >= 4,
              frame[0] == 0, frame[1] == 0,
              frame[2] == 2, frame[3] == 2 else { return nil }
        return frame.dropFirst(4)
    }

    static let singlePacketAcknowledgement = Data([0x00, 0x00, 0x03, 0x00])

    private static func hmac(key: Data, data: Data) -> Data {
        let key = SymmetricKey(data: key)
        return Data(CryptoKit.HMAC<CryptoKit.SHA256>.authenticationCode(for: data, using: key))
    }

    private static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) { difference |= left ^ right }
        return difference == 0
    }

    private static func encryptCCM(
        _ plaintext: Data,
        key: Data,
        noncePrefix: Data,
        counter: UInt32
    ) throws -> Data {
        guard key.count == 16, noncePrefix.count == 4 else {
            throw MiBandAuthProtocolError.encryptionFailed
        }
        var nonce = noncePrefix + Data(repeating: 0, count: 4)
        var littleEndianCounter = counter.littleEndian
        withUnsafeBytes(of: &littleEndianCounter) { nonce.append(contentsOf: $0) }
        do {
            let mode = CCM(iv: Array(nonce), tagLength: 4, messageLength: plaintext.count)
            let aes = try AES(key: Array(key), blockMode: mode, padding: .noPadding)
            return Data(try aes.encrypt(Array(plaintext)))
        } catch {
            throw MiBandAuthProtocolError.encryptionFailed
        }
    }

    private static func fieldVarint(_ number: UInt64, _ value: UInt64) -> Data {
        var output = encodeVarint((number << 3) | 0)
        output.append(encodeVarint(value))
        return output
    }

    private static func fieldBytes(_ number: UInt64, _ value: Data) -> Data {
        var output = encodeVarint((number << 3) | 2)
        output.append(encodeVarint(UInt64(value.count)))
        output.append(value)
        return output
    }

    private static func fieldMessage(_ number: UInt64, _ value: Data) -> Data {
        fieldBytes(number, value)
    }

    private static func fieldString(_ number: UInt64, _ value: String) -> Data {
        fieldBytes(number, Data(value.utf8))
    }

    private static func fieldFloat(_ number: UInt64, _ value: Float) -> Data {
        var bits = value.bitPattern.littleEndian
        var output = encodeVarint((number << 3) | 5)
        withUnsafeBytes(of: &bits) { output.append(contentsOf: $0) }
        return output
    }

    private static func encodeVarint(_ value: UInt64) -> Data {
        var value = value
        var output = Data()
        repeat {
            var byte = UInt8(value & 0x7F)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            output.append(byte)
        } while value != 0
        return output
    }
}

private struct ProtobufFields {
    private var varints: [UInt64: UInt64] = [:]
    private var byteFields: [UInt64: Data] = [:]

    init(_ data: Data) throws {
        var offset = 0
        while offset < data.count {
            let key = try Self.readVarint(data, offset: &offset)
            let field = key >> 3
            switch key & 7 {
            case 0:
                varints[field] = try Self.readVarint(data, offset: &offset)
            case 1:
                guard offset + 8 <= data.count else { throw MiBandAuthProtocolError.malformedResponse }
                offset += 8
            case 2:
                let length = try Self.readVarint(data, offset: &offset)
                guard length <= UInt64(Int.max) else { throw MiBandAuthProtocolError.malformedResponse }
                let end = offset + Int(length)
                guard end <= data.count else { throw MiBandAuthProtocolError.malformedResponse }
                byteFields[field] = data.subdata(in: offset..<end)
                offset = end
            case 5:
                guard offset + 4 <= data.count else { throw MiBandAuthProtocolError.malformedResponse }
                offset += 4
            default:
                throw MiBandAuthProtocolError.malformedResponse
            }
        }
    }

    func varint(_ field: UInt64) -> UInt64? { varints[field] }
    func bytes(_ field: UInt64) -> Data? { byteFields[field] }

    private static func readVarint(_ data: Data, offset: inout Int) throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count, shift < 64 {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        throw MiBandAuthProtocolError.malformedResponse
    }
}
