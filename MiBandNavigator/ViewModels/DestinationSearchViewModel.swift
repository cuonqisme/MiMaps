import Combine
import Foundation

@MainActor
final class DestinationSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var suggestions: [DestinationSuggestion] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let searchService: PlacesSearching
    private let sharedLocationImporter: SharedLocationImporting?

    init(
        searchService: PlacesSearching,
        sharedLocationImporter: SharedLocationImporting? = nil
    ) {
        self.searchService = searchService
        self.sharedLocationImporter = sharedLocationImporter
    }

    func search() async {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else {
            suggestions = []
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            suggestions = try await searchService.autocomplete(query: normalized)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            suggestions = []
            errorMessage = error.localizedDescription
        }
    }

    func select(_ suggestion: DestinationSuggestion) async -> Destination? {
        isLoading = true
        defer { isLoading = false }
        do {
            let destination = try await searchService.resolve(suggestion)
            errorMessage = nil
            return destination
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func importSharedLink(_ text: String) async -> Destination? {
        guard let sharedLocationImporter else {
            errorMessage = SharedMapLocationError.unsupportedLink.localizedDescription
            return nil
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let destination = try await sharedLocationImporter.importDestination(from: text)
            errorMessage = nil
            return destination
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func cancel() {
        searchService.resetSession()
    }
}
