import Combine
import Foundation

@MainActor
final class DestinationSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var suggestions: [DestinationSuggestion] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let searchService: PlacesSearching

    init(searchService: PlacesSearching) {
        self.searchService = searchService
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

    func cancel() {
        searchService.resetSession()
    }
}

