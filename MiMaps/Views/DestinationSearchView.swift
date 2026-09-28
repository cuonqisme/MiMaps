import SwiftUI
import UIKit

struct DestinationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DestinationSearchViewModel
    @FocusState private var isSearchFocused: Bool
    let recentDestinations: [Destination]
    let onClearRecent: () -> Void
    let onSelection: (Destination) -> Void

    init(
        searchService: PlacesSearching,
        sharedLocationImporter: SharedLocationImporting? = nil,
        recentDestinations: [Destination] = [],
        onClearRecent: @escaping () -> Void = {},
        onSelection: @escaping (Destination) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: DestinationSearchViewModel(
                searchService: searchService,
                sharedLocationImporter: sharedLocationImporter
            )
        )
        self.recentDestinations = recentDestinations
        self.onClearRecent = onClearRecent
        self.onSelection = onSelection
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                Divider()

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 10)
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        googleMapsImportButton

                        if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if recentDestinations.isEmpty {
                                searchHint
                            } else {
                                recentDestinationsSection
                            }
                        } else if !viewModel.isLoading && viewModel.suggestions.isEmpty
                                    && viewModel.errorMessage == nil {
                            emptyState(
                                title: "Không có kết quả",
                                systemImage: "mappin.slash",
                                description: "Thử thêm quận, thành phố hoặc địa chỉ cụ thể."
                            )
                        }

                        ForEach(viewModel.suggestions) { suggestion in
                            suggestionRow(suggestion)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                                .textSelection(.enabled)
                        }
                    }
                    .padding(16)
                }

                Label("Kết quả từ Apple Maps", systemImage: "apple.logo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: viewModel.query) {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    await viewModel.search()
                } catch {
                    return
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(250))
                isSearchFocused = true
            }
            .onDisappear { viewModel.cancel() }
        }
        .presentationDragIndicator(.visible)
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.cancel()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Đóng tìm kiếm")

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Tìm địa điểm hoặc địa chỉ", text: $viewModel.query)
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                    .submitLabel(.search)
                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Xóa nội dung tìm kiếm")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var googleMapsImportButton: some View {
        Button {
            Task {
                if let destination = await viewModel.importSharedLink(
                    UIPasteboard.general.string ?? ""
                ) {
                    onSelection(destination)
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 38, height: 38)
                    .background(Color.blue.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nhập liên kết Google Maps")
                        .font(.subheadline.bold())
                    Text("Sao chép liên kết trong Google Maps rồi bấm vào đây")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var searchHint: some View {
        emptyState(
            title: "Bạn muốn đi đâu?",
            systemImage: "map.fill",
            description: "Nhập tên địa điểm, địa chỉ, quận hoặc thành phố để có kết quả chính xác hơn."
        )
    }

    private var recentDestinationsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Gần đây")
                    .font(.headline)
                Spacer()
                Button("Xóa") { onClearRecent() }
                    .font(.subheadline)
            }
            .padding(.horizontal, 4)

            ForEach(recentDestinations) { destination in
                Button {
                    onSelection(destination)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color.secondary.opacity(0.1), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(destination.displayName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let address = destination.formattedAddress {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(
                        Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func emptyState(title: String, systemImage: String, description: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
        }
        .padding(.top, 36)
        .padding(.horizontal, 20)
    }

    private func suggestionRow(_ suggestion: DestinationSuggestion) -> some View {
        Button {
            Task {
                if let destination = await viewModel.select(suggestion) {
                    onSelection(destination)
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.primaryText)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let secondaryText = suggestion.secondaryText {
                        Text(secondaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.left")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
