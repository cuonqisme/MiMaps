import Combine
import Foundation

enum BandDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case routeCard
    case compact

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .routeCard: "Thẻ chỉ đường"
        case .compact: "Gọn, tương thích"
        }
    }

    var localizedDescription: String {
        switch self {
        case .routeCard:
            "Hiển thị hướng, khoảng cách, tên đường, thời gian và quãng đường còn lại."
        case .compact:
            "Chỉ gửi hướng, khoảng cách và tên đường để dễ đọc trên màn hình nhỏ."
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let bandNotificationsEnabled = "bandNotificationsEnabled"
        static let notificationSoundEnabled = "notificationSoundEnabled"
        static let developerModeEnabled = "developerModeEnabled"
        static let travelMode = "travelMode"
        static let mapDisplayStyle = "mapDisplayStyle"
        static let showTraffic = "showTraffic"
        static let showSpeedLimit = "showSpeedLimit"
        static let bandDisplayStyle = "bandDisplayStyle"
        static let recentDestinations = "recentDestinations"
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

    @Published var showTraffic: Bool {
        didSet { defaults.set(showTraffic, forKey: Key.showTraffic) }
    }

    @Published var showSpeedLimit: Bool {
        didSet { defaults.set(showSpeedLimit, forKey: Key.showSpeedLimit) }
    }

    @Published var bandDisplayStyle: BandDisplayStyle {
        didSet { defaults.set(bandDisplayStyle.rawValue, forKey: Key.bandDisplayStyle) }
    }

    @Published private(set) var recentDestinations: [Destination]

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
        showTraffic = defaults.object(forKey: Key.showTraffic) as? Bool ?? true
        showSpeedLimit = defaults.object(forKey: Key.showSpeedLimit) as? Bool ?? true
        bandDisplayStyle = BandDisplayStyle(
            rawValue: defaults.string(forKey: Key.bandDisplayStyle) ?? ""
        ) ?? .routeCard
        recentDestinations = Self.storedDestinations(defaults: defaults)
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

    func recordRecentDestination(_ destination: Destination) {
        var updated = recentDestinations.filter { existing in
            if let placeID = destination.placeID, let existingPlaceID = existing.placeID {
                return placeID != existingPlaceID
            }
            return abs(existing.latitude - destination.latitude) > 0.000_01
                || abs(existing.longitude - destination.longitude) > 0.000_01
        }
        updated.insert(destination, at: 0)
        recentDestinations = Array(updated.prefix(8))
        persistRecentDestinations()
    }

    func clearRecentDestinations() {
        recentDestinations = []
        defaults.removeObject(forKey: Key.recentDestinations)
    }

    private func persistRecentDestinations() {
        guard let data = try? JSONEncoder().encode(recentDestinations) else { return }
        defaults.set(data, forKey: Key.recentDestinations)
    }

    private static func storedDestinations(defaults: UserDefaults) -> [Destination] {
        guard let data = defaults.data(forKey: Key.recentDestinations),
              let values = try? JSONDecoder().decode([Destination].self, from: data) else {
            return []
        }
        return Array(values.prefix(8))
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
