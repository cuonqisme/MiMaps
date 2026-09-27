import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let bandNotificationsEnabled = "bandNotificationsEnabled"
        static let notificationSoundEnabled = "notificationSoundEnabled"
        static let developerModeEnabled = "developerModeEnabled"
        static let travelMode = "travelMode"
        static let mapDisplayStyle = "mapDisplayStyle"
        static let avoidTolls = "avoidTolls"
        static let avoidHighways = "avoidHighways"
        static let farThresholdMeters = "farThresholdMeters"
        static let mediumThresholdMeters = "mediumThresholdMeters"
        static let nearThresholdMeters = "nearThresholdMeters"
        static let immediateThresholdMeters = "immediateThresholdMeters"
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

    @Published var travelMode: TravelMode {
        didSet { defaults.set(travelMode.rawValue, forKey: Key.travelMode) }
    }

    @Published var mapDisplayStyle: MapDisplayStyle {
        didSet { defaults.set(mapDisplayStyle.rawValue, forKey: Key.mapDisplayStyle) }
    }

    @Published var avoidTolls: Bool {
        didSet { defaults.set(avoidTolls, forKey: Key.avoidTolls) }
    }

    @Published var avoidHighways: Bool {
        didSet { defaults.set(avoidHighways, forKey: Key.avoidHighways) }
    }

    @Published var farThresholdMeters: Int {
        didSet { defaults.set(farThresholdMeters, forKey: Key.farThresholdMeters) }
    }

    @Published var mediumThresholdMeters: Int {
        didSet { defaults.set(mediumThresholdMeters, forKey: Key.mediumThresholdMeters) }
    }

    @Published var nearThresholdMeters: Int {
        didSet { defaults.set(nearThresholdMeters, forKey: Key.nearThresholdMeters) }
    }

    @Published var immediateThresholdMeters: Int {
        didSet { defaults.set(immediateThresholdMeters, forKey: Key.immediateThresholdMeters) }
    }

    var notificationThresholds: [Int] {
        [farThresholdMeters, mediumThresholdMeters, nearThresholdMeters, immediateThresholdMeters]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bandNotificationsEnabled = defaults.object(forKey: Key.bandNotificationsEnabled) as? Bool ?? true
        notificationSoundEnabled = defaults.object(forKey: Key.notificationSoundEnabled) as? Bool ?? false
        developerModeEnabled = defaults.object(forKey: Key.developerModeEnabled) as? Bool ?? false
        travelMode = TravelMode(rawValue: defaults.string(forKey: Key.travelMode) ?? "") ?? .motorcycle
        mapDisplayStyle = MapDisplayStyle(
            rawValue: defaults.string(forKey: Key.mapDisplayStyle) ?? ""
        ) ?? .standard
        avoidTolls = defaults.object(forKey: Key.avoidTolls) as? Bool ?? false
        avoidHighways = defaults.object(forKey: Key.avoidHighways) as? Bool ?? false
        farThresholdMeters = Self.storedPositiveInt(
            defaults: defaults,
            key: Key.farThresholdMeters,
            fallback: 500
        )
        mediumThresholdMeters = Self.storedPositiveInt(
            defaults: defaults,
            key: Key.mediumThresholdMeters,
            fallback: 200
        )
        nearThresholdMeters = Self.storedPositiveInt(
            defaults: defaults,
            key: Key.nearThresholdMeters,
            fallback: 80
        )
        immediateThresholdMeters = Self.storedPositiveInt(
            defaults: defaults,
            key: Key.immediateThresholdMeters,
            fallback: 30
        )
    }

    var routePreferences: RoutePreferences {
        RoutePreferences(avoidTolls: avoidTolls, avoidHighways: avoidHighways)
    }

    private static func storedPositiveInt(
        defaults: UserDefaults,
        key: String,
        fallback: Int
    ) -> Int {
        guard let stored = defaults.object(forKey: key) as? NSNumber, stored.intValue > 0 else {
            return fallback
        }
        return stored.intValue
    }
}
