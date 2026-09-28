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
    private var searchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 16.0, longitude: 106.0),
        span: MKCoordinateSpan(latitudeDelta: 16.0, longitudeDelta: 12.0)
    )

    func updateSearchCenter(_ coordinate: CLLocationCoordinate2D) {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        searchRegion = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 80_000,
            longitudinalMeters: 80_000
        )
    }

    func searchNearby(
        category: NearbyPlaceCategory,
        center: CLLocationCoordinate2D
    ) async throws -> [Destination] {
        guard CLLocationCoordinate2DIsValid(center) else { return [] }
        var mapItems: [MKMapItem] = []
        var lastServiceError: Error?

        let pointOfInterestRequest = MKLocalPointsOfInterestRequest(center: center, radius: 20_000)
        pointOfInterestRequest.pointOfInterestFilter = MKPointOfInterestFilter(
            including: category.pointOfInterestCategories
        )

        do {
            mapItems = try await execute(MKLocalSearch(request: pointOfInterestRequest))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if !isNoResultsError(error) { lastServiceError = error }
        }

        if mapItems.isEmpty {
            for query in category.fallbackSearchQueries {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = .pointOfInterest
                request.region = MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: 60_000,
                    longitudinalMeters: 60_000
                )

                do {
                    mapItems.append(contentsOf: try await execute(MKLocalSearch(request: request)))
                    if !mapItems.isEmpty { break }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    if !isNoResultsError(error) { lastServiceError = error }
                }
            }
        }

        let destinations = nearbyDestinations(
            from: mapItems,
            category: category,
            center: center
        )
        if destinations.isEmpty, let lastServiceError {
            throw PlacesSearchError.searchFailed(userFacingMessage(for: lastServiceError))
        }
        return destinations
    }

    func autocomplete(query: String) async throws -> [DestinationSuggestion] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        activeSearch?.cancel()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = normalized
        request.resultTypes = [.address, .pointOfInterest]
        request.region = searchRegion
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
            phoneNumber: item.phoneNumber,
            websiteURL: item.url,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    func resetSession() {
        activeSearch?.cancel()
        activeSearch = nil
        cachedItems.removeAll(keepingCapacity: false)
    }

    private func execute(_ search: MKLocalSearch) async throws -> [MKMapItem] {
        activeSearch?.cancel()
        activeSearch = search
        do {
            let response = try await search.start()
            guard activeSearch === search else { throw CancellationError() }
            return response.mapItems
        } catch {
            guard activeSearch === search else { throw CancellationError() }
            throw error
        }
    }

    private func nearbyDestinations(
        from mapItems: [MKMapItem],
        category: NearbyPlaceCategory,
        center: CLLocationCoordinate2D
    ) -> [Destination] {
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
        var seen = Set<String>()

        let destinations = mapItems.compactMap { item -> Destination? in
            let coordinate = coordinate(for: item)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard origin.distance(from: location) <= 60_000 else { return nil }

            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = name?.isEmpty == false ? name ?? category.localizedName : category.localizedName
            let deduplicationKey = String(
                format: "%.5f:%.5f:%@",
                locale: Locale(identifier: "en_US_POSIX"),
                coordinate.latitude,
                coordinate.longitude,
                displayName.lowercased()
            )
            guard seen.insert(deduplicationKey).inserted else { return nil }

            return Destination(
                placeID: String(
                    format: "apple-nearby:%.7f,%.7f",
                    locale: Locale(identifier: "en_US_POSIX"),
                    coordinate.latitude,
                    coordinate.longitude
                ),
                displayName: displayName,
                formattedAddress: formattedAddress(for: item),
                phoneNumber: item.phoneNumber,
                websiteURL: item.url,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }

        return Array(
            destinations.sorted { lhs, rhs in
                let left = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
                let right = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
                return origin.distance(from: left) < origin.distance(from: right)
            }.prefix(30)
        )
    }

    private func isNoResultsError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "MKErrorDomain"
            && nsError.code >= 0
            && UInt(nsError.code) == MKError.Code.placemarkNotFound.rawValue
    }

    private func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == "MKErrorDomain" else {
            return "Không thể kết nối dịch vụ bản đồ. Hãy kiểm tra mạng và thử lại."
        }

        guard nsError.code >= 0,
              let code = MKError.Code(rawValue: UInt(nsError.code)) else {
            return "Không thể tải địa điểm từ Apple Maps. Hãy kiểm tra mạng và thử lại."
        }

        switch code {
        case .loadingThrottled:
            return "Apple Maps đang giới hạn yêu cầu. Hãy đợi một lát rồi thử lại."
        case .serverFailure:
            return "Dịch vụ Apple Maps đang tạm thời không phản hồi. Hãy thử lại sau."
        case .placemarkNotFound:
            return "Không tìm thấy địa điểm phù hợp gần đây."
        default:
            return "Không thể tải địa điểm từ Apple Maps. Hãy kiểm tra mạng và thử lại."
        }
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

private extension NearbyPlaceCategory {
    var pointOfInterestCategories: [MKPointOfInterestCategory] {
        switch self {
        case .food: [.restaurant, .foodMarket, .bakery]
        case .fuel: [.gasStation]
        case .parking: [.parking]
        case .hospital: [.hospital]
        case .pharmacy: [.pharmacy]
        case .atm: [.atm, .bank]
        case .coffee: [.cafe]
        case .hotel: [.hotel]
        }
    }
}
