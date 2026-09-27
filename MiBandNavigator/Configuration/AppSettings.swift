import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let bandNotificationsEnabled = "bandNotificationsEnabled"
        static let notificationSoundEnabled = "notificationSoundEnabled"
        static let developerModeEnabled = "developerModeEnabled"
    }

    private let defaults: UserDefaults

    @Published var bandNotificationsEnabled: Bool {
        didSet { defaults.set(bandNotificationsEnabled, forKey: Key.bandNotificationsEnabled) }
    }

    @Published var notificationSoundEnabled: Bool {
        didSet { defaults.set(notificationSoundEnabled, forKey: Key.notificationSoundEnabled) }
    }

    @Published var developerModeEnabled: Bool {
        didSet { defaults.set(developerModeEnabled, forKey: Key.developerModeEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bandNotificationsEnabled = defaults.object(forKey: Key.bandNotificationsEnabled) as? Bool ?? true
        notificationSoundEnabled = defaults.object(forKey: Key.notificationSoundEnabled) as? Bool ?? false
        developerModeEnabled = defaults.object(forKey: Key.developerModeEnabled) as? Bool ?? false
    }
}

