import SwiftUI

struct DestinationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DestinationSearchViewModel
    let onSelection: (Destination) -> Void

    init(searchService: PlacesSearching, onSelection: @escaping (Destination) -> Void) {
        _viewModel = StateObject(wrappedValue: DestinationSearchViewModel(searchService: searchService))
        self.onSelection = onSelection
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                ForEach(viewModel.suggestions) { suggestion in
                    Button {
                        Task {
                            if let destination = await viewModel.select(suggestion) {
                                onSelection(destination)
                                dismiss()
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.primaryText)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let secondaryText = suggestion.secondaryText {
                                Text(secondaryText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Label("Dữ liệu bản đồ Apple", systemImage: "apple.logo")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
                    .accessibilityLabel("Dữ liệu bản đồ Apple")
            }
            .navigationTitle("Tìm điểm đến")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Tên địa điểm hoặc địa chỉ")
            .task(id: viewModel.query) {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    await viewModel.search()
                } catch {
                    return
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        viewModel.cancel()
                        dismiss()
                    }
                }
            }
        }
    }
}
