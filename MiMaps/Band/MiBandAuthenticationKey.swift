import Foundation
import Security

enum MiBandAuthenticationKey {
    static let byteCount = 16

    static func normalize(_ value: String) -> String? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        guard normalized.count == byteCount * 2,
              normalized.allSatisfy(\.isHexDigit) else {
            return nil
        }
        return normalized
    }

    static func fingerprint(_ normalizedKey: String) -> String {
        let suffix = normalizedKey.suffix(4)
        return "••••••••\(suffix)"
    }
}

protocol MiBandCredentialStoring: AnyObject {
    func save(authenticationKey: String) throws
    func loadAuthenticationKey() -> String?
    func deleteAuthenticationKey() throws
}

enum MiBandCredentialStoreError: LocalizedError {
    case invalidKey
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            "Khóa xác thực phải gồm đúng 32 ký tự hex."
        case let .keychain(status):
            "Keychain trả về lỗi \(status)."
        }
    }
}

final class MiBandCredentialStore: MiBandCredentialStoring {
    private let service = "com.example.mibandnavigator.band"
    private let account = "xiaomi-smart-band-8-auth-key"

    func save(authenticationKey: String) throws {
        guard let normalized = MiBandAuthenticationKey.normalize(authenticationKey),
              let data = normalized.data(using: .utf8) else {
            throw MiBandCredentialStoreError.invalidKey
        }

        let query = baseQuery()
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MiBandCredentialStoreError.keychain(status)
        }
    }

    func loadAuthenticationKey() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return MiBandAuthenticationKey.normalize(value)
    }

    func deleteAuthenticationKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MiBandCredentialStoreError.keychain(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
