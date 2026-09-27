import Foundation
import GooglePlacesSwift

struct DestinationSuggestion: Sendable, Equatable, Hashable, Identifiable {
    let placeID: String
    let primaryText: String
    let secondaryText: String?

    var id: String { placeID }
}

enum PlacesSearchError: LocalizedError, Equatable {
    case configurationMissing
    case searchFailed(String)
    case detailsFailed(String)
    case invalidPlace

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            "Chưa cấu hình GOOGLE_MAPS_API_KEY hoặc chưa bật Places API (New)."
        case let .searchFailed(message):
            "Không thể tìm địa điểm: \(message)"
        case let .detailsFailed(message):
            "Không thể tải chi tiết địa điểm: \(message)"
        case .invalidPlace:
            "Địa điểm không có đủ tên hoặc tọa độ để điều hướng."
        }
    }
}

@MainActor
protocol PlacesSearching: AnyObject {
    func autocomplete(query: String) async throws -> [DestinationSuggestion]
    func resolve(_ suggestion: DestinationSuggestion) async throws -> Destination
    func resetSession()
}

@MainActor
final class GooglePlacesSearchService: PlacesSearching {
    private var sessionToken = AutocompleteSessionToken()

    func autocomplete(query: String) async throws -> [DestinationSuggestion] {
        guard AppConfig.googleMapsAPIKey != nil else { throw PlacesSearchError.configurationMissing }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        let request = AutocompleteRequest(query: normalized, sessionToken: sessionToken)
        switch await PlacesClient.shared.fetchAutocompleteSuggestions(with: request) {
        case let .success(values):
            return values.compactMap { value in
                guard case let .place(place) = value else { return nil }
                return DestinationSuggestion(
                    placeID: place.placeID,
                    primaryText: String(place.attributedPrimaryText.characters),
                    secondaryText: place.attributedSecondaryText.map { String($0.characters) }
                )
            }
        case let .failure(error):
            throw PlacesSearchError.searchFailed(String(describing: error))
        }
    }

    func resolve(_ suggestion: DestinationSuggestion) async throws -> Destination {
        guard AppConfig.googleMapsAPIKey != nil else { throw PlacesSearchError.configurationMissing }
        let request = FetchPlaceRequest(
            placeID: suggestion.placeID,
            placeProperties: [.placeID, .displayName, .formattedAddress, .coordinate],
            sessionToken: sessionToken
        )

        switch await PlacesClient.shared.fetchPlace(with: request) {
        case let .success(place):
            defer { resetSession() }
            return Destination(
                placeID: place.placeID ?? suggestion.placeID,
                displayName: place.displayName ?? suggestion.primaryText,
                formattedAddress: place.formattedAddress ?? suggestion.secondaryText,
                latitude: place.location.latitude,
                longitude: place.location.longitude
            )
        case let .failure(error):
            throw PlacesSearchError.detailsFailed(String(describing: error))
        }
    }

    func resetSession() {
        sessionToken = AutocompleteSessionToken()
    }
}

