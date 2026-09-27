import Foundation

enum GoogleAPIConfigurationStatus: Sendable, Equatable {
    case configured
    case missing
}

enum GoogleAPIKeyValidator {
    static func normalizedKey(_ value: Any?) -> String? {
        guard let rawValue = value as? String else { return nil }
        let key = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty,
              key != "YOUR_GOOGLE_MAPS_API_KEY",
              !key.contains("$(") else {
            return nil
        }
        return key
    }
}

enum AppConfig {
    static let googleMapsSDKVersion = "11.2.0"
    static let googleNavigationSDKVersion = "11.2.0"
    static let googlePlacesSDKVersion = "11.1.0"

    static var googleMapsAPIKey: String? {
        GoogleAPIKeyValidator.normalizedKey(
            Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY")
        )
    }

    static var googleAPIConfigurationStatus: GoogleAPIConfigurationStatus {
        googleMapsAPIKey == nil ? .missing : .configured
    }
}
