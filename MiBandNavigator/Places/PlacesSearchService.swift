import Foundation
import MapKit

struct DestinationSuggestion: Sendable, Equatable, Hashable, Identifiable {
    let placeID: String
    let primaryText: String
    let secondaryText: String?

    var id: String { placeID }
}

enum PlacesSearchError: LocalizedError, Equatable {
    case searchFailed(String)
    case detailsFailed(String)
    case invalidPlace

    var errorDescription: String? {
        switch self {
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
final class ApplePlacesSearchService: PlacesSearching {
    private var cachedItems: [String: MKMapItem] = [:]
    private var activeSearch: MKLocalSearch?

    func autocomplete(query: String) async throws -> [DestinationSuggestion] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        activeSearch?.cancel()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = normalized
        request.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: request)
        activeSearch = search

        do {
            let response = try await search.start()
            guard activeSearch === search else { throw CancellationError() }
            cachedItems.removeAll(keepingCapacity: true)

            return response.mapItems.prefix(20).map { item in
                let coordinate = coordinate(for: item)
                let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let primaryText = (name?.isEmpty == false ? name : nil) ?? normalized
                let identifier = String(
                    format: "apple:%.7f,%.7f:%@",
                    locale: Locale(identifier: "en_US_POSIX"),
                    coordinate.latitude,
                    coordinate.longitude,
                    primaryText
                )
                cachedItems[identifier] = item
                return DestinationSuggestion(
                    placeID: identifier,
                    primaryText: primaryText,
                    secondaryText: formattedAddress(for: item)
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PlacesSearchError.searchFailed(error.localizedDescription)
        }
    }

    func resolve(_ suggestion: DestinationSuggestion) async throws -> Destination {
        guard let item = cachedItems[suggestion.placeID] else {
            throw PlacesSearchError.detailsFailed("Kết quả tìm kiếm đã hết hạn, vui lòng tìm lại.")
        }
        let coordinate = coordinate(for: item)
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            throw PlacesSearchError.invalidPlace
        }

        return Destination(
            placeID: suggestion.placeID,
            displayName: suggestion.primaryText,
            formattedAddress: suggestion.secondaryText,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    func resetSession() {
        activeSearch?.cancel()
        activeSearch = nil
        cachedItems.removeAll(keepingCapacity: false)
    }

    private func coordinate(for item: MKMapItem) -> CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return item.location.coordinate
        } else {
            return item.placemark.coordinate
        }
    }

    private func formattedAddress(for item: MKMapItem) -> String? {
        if #available(iOS 26.0, *) {
            return item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
                ?? item.address?.fullAddress
        } else {
            return item.placemark.title
        }
    }
}
