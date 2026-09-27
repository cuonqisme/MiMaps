import XCTest
@testable import MiBandNavigator

@MainActor
final class DestinationSearchViewModelTests: XCTestCase {
    func testShortQueryDoesNotCallService() async {
        let service = PlacesSearchServiceFake()
        let viewModel = DestinationSearchViewModel(searchService: service)
        viewModel.query = "a"

        await viewModel.search()

        XCTAssertEqual(service.queries, [])
        XCTAssertEqual(viewModel.suggestions, [])
    }

    func testSearchPublishesSuggestions() async {
        let expected = DestinationSuggestion(
            placeID: "place-1",
            primaryText: "Hồ Hoàn Kiếm",
            secondaryText: "Hoàn Kiếm, Hà Nội"
        )
        let service = PlacesSearchServiceFake(suggestions: [expected])
        let viewModel = DestinationSearchViewModel(searchService: service)
        viewModel.query = "Hồ Hoàn Kiếm"

        await viewModel.search()

        XCTAssertEqual(service.queries, ["Hồ Hoàn Kiếm"])
        XCTAssertEqual(viewModel.suggestions, [expected])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSelectionReturnsProviderNeutralDestination() async {
        let suggestion = DestinationSuggestion(placeID: "place-1", primaryText: "Test", secondaryText: nil)
        let expected = Destination(
            placeID: "place-1",
            displayName: "Test",
            formattedAddress: "Hà Nội",
            latitude: 21,
            longitude: 105
        )
        let service = PlacesSearchServiceFake(suggestions: [], destination: expected)
        let viewModel = DestinationSearchViewModel(searchService: service)

        let destination = await viewModel.select(suggestion)

        XCTAssertEqual(destination, expected)
        XCTAssertEqual(service.resolvedSuggestions, [suggestion])
    }

    func testSearchErrorIsExposed() async {
        let service = PlacesSearchServiceFake(error: PlacesSearchError.configurationMissing)
        let viewModel = DestinationSearchViewModel(searchService: service)
        viewModel.query = "Hà Nội"

        await viewModel.search()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.suggestions.isEmpty)
    }
}

@MainActor
private final class PlacesSearchServiceFake: PlacesSearching {
    let suggestions: [DestinationSuggestion]
    let destination: Destination?
    let error: Error?
    private(set) var queries: [String] = []
    private(set) var resolvedSuggestions: [DestinationSuggestion] = []

    init(
        suggestions: [DestinationSuggestion] = [],
        destination: Destination? = nil,
        error: Error? = nil
    ) {
        self.suggestions = suggestions
        self.destination = destination
        self.error = error
    }

    func autocomplete(query: String) async throws -> [DestinationSuggestion] {
        queries.append(query)
        if let error { throw error }
        return suggestions
    }

    func resolve(_ suggestion: DestinationSuggestion) async throws -> Destination {
        resolvedSuggestions.append(suggestion)
        if let error { throw error }
        guard let destination else { throw PlacesSearchError.invalidPlace }
        return destination
    }

    func resetSession() {}
}

