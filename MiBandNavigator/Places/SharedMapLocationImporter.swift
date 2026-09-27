import CoreLocation
import Foundation

enum SharedMapLocation: Equatable, Sendable {
    case coordinate(latitude: Double, longitude: Double, name: String?)
    case searchQuery(String)
}

enum SharedMapLocationError: LocalizedError, Equatable {
    case emptyClipboard
    case invalidURL
    case unsupportedLink
    case noSearchResult

    var errorDescription: String? {
        switch self {
        case .emptyClipboard: "Clipboard không có liên kết Google Maps."
        case .invalidURL: "Liên kết Google Maps không hợp lệ."
        case .unsupportedLink: "Không đọc được vị trí trong liên kết này."
        case .noSearchResult: "Không tìm thấy địa điểm được chia sẻ."
        }
    }
}

@MainActor
protocol SharedLocationImporting: AnyObject {
    func importDestination(from text: String) async throws -> Destination
}

struct SharedMapLinkParser {
    func parse(_ url: URL) -> SharedMapLocation? {
        let absolute = url.absoluteString.removingPercentEncoding ?? url.absoluteString
        let name = placeName(from: url)

        if let coordinate = coordinate(
            in: absolute,
            pattern: #"!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)"#
        ) {
            return .coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude, name: name)
        }

        if let coordinate = coordinate(
            in: absolute,
            pattern: #"/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)"#
        ) {
            return .coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude, name: name)
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let preferredKeys = ["destination", "daddr", "query", "q", "ll", "center"]
        for key in preferredKeys {
            guard let value = components?.queryItems?.first(where: { $0.name == key })?.value,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let decodedValue = value.replacingOccurrences(of: "+", with: " ")
            if let coordinate = coordinate(from: decodedValue) {
                return .coordinate(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    name: name
                )
            }
            return .searchQuery(decodedValue)
        }

        if let name { return .searchQuery(name) }
        return nil
    }

    private func coordinate(in value: String, pattern: String) -> CLLocationCoordinate2D? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
              ),
              match.numberOfRanges >= 3,
              let latitudeRange = Range(match.range(at: 1), in: value),
              let longitudeRange = Range(match.range(at: 2), in: value),
              let latitude = Double(value[latitudeRange]),
              let longitude = Double(value[longitudeRange]) else { return nil }
        return validatedCoordinate(latitude: latitude, longitude: longitude)
    }

    private func coordinate(from value: String) -> CLLocationCoordinate2D? {
        let normalized = value
            .replacingOccurrences(of: "geo:", with: "")
            .replacingOccurrences(of: " ", with: "")
        let parts = normalized.split(separator: ",", maxSplits: 2)
        guard parts.count >= 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]) else { return nil }
        return validatedCoordinate(latitude: latitude, longitude: longitude)
    }

    private func validatedCoordinate(latitude: Double, longitude: Double) -> CLLocationCoordinate2D? {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    private func placeName(from url: URL) -> String? {
        let parts = url.pathComponents
        guard let placeIndex = parts.firstIndex(of: "place"), placeIndex + 1 < parts.count else {
            return nil
        }
        let encodedValue = parts[placeIndex + 1]
            .replacingOccurrences(of: "+", with: " ")
        let value = (encodedValue.removingPercentEncoding ?? encodedValue)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

@MainActor
final class GoogleMapsLocationImporter: SharedLocationImporting {
    private let searchService: PlacesSearching
    private let parser: SharedMapLinkParser
    private let session: URLSession

    init(
        searchService: PlacesSearching,
        parser: SharedMapLinkParser = SharedMapLinkParser(),
        session: URLSession = .shared
    ) {
        self.searchService = searchService
        self.parser = parser
        self.session = session
    }

    func importDestination(from text: String) async throws -> Destination {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw SharedMapLocationError.emptyClipboard }
        guard let suppliedURL = URL(string: normalized), suppliedURL.scheme?.hasPrefix("http") == true else {
            throw SharedMapLocationError.invalidURL
        }

        var parsed = parser.parse(suppliedURL)
        if parsed == nil || isShortGoogleURL(suppliedURL) {
            let (_, response) = try await session.data(from: suppliedURL)
            if let resolvedURL = response.url {
                parsed = parser.parse(resolvedURL) ?? parsed
            }
        }

        guard let parsed else { throw SharedMapLocationError.unsupportedLink }
        switch parsed {
        case let .coordinate(latitude, longitude, name):
            return Destination(
                displayName: name ?? "Điểm chia sẻ từ Google Maps",
                formattedAddress: "\(latitude), \(longitude)",
                latitude: latitude,
                longitude: longitude
            )
        case let .searchQuery(query):
            guard let first = try await searchService.autocomplete(query: query).first else {
                throw SharedMapLocationError.noSearchResult
            }
            return try await searchService.resolve(first)
        }
    }

    private func isShortGoogleURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "maps.app.goo.gl" || host == "goo.gl"
    }
}
