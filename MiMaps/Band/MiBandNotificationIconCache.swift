import Foundation

/// Persists notification-icon aliases that a specific Band has already
/// accepted. Xiaomi keeps these icons across BLE reconnects, so treating every
/// new secure session as an empty cache adds a five-second delay and starts a
/// package-query handshake that the Band intentionally skips.
struct MiBandNotificationIconCache {
    private static let keyPrefix = "directMiBandNotificationIconCache."

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func contains(package: String, deviceIdentifier: UUID?) -> Bool {
        guard let key = storageKey(deviceIdentifier: deviceIdentifier) else { return false }
        return Set(defaults.stringArray(forKey: key) ?? []).contains(package)
    }

    func insert(package: String, deviceIdentifier: UUID?) {
        guard let key = storageKey(deviceIdentifier: deviceIdentifier) else { return }
        var packages = Set(defaults.stringArray(forKey: key) ?? [])
        packages.insert(package)
        defaults.set(packages.sorted(), forKey: key)
    }

    func removeAll(deviceIdentifier: UUID?) {
        guard let key = storageKey(deviceIdentifier: deviceIdentifier) else { return }
        defaults.removeObject(forKey: key)
    }

    private func storageKey(deviceIdentifier: UUID?) -> String? {
        deviceIdentifier.map { Self.keyPrefix + $0.uuidString.lowercased() }
    }
}
