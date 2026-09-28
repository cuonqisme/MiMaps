import CoreLocation
import SwiftUI
import UIKit

struct NearbyPlacesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: NearbyPlaceCategory
    let destinations: [Destination]
    let userCoordinate: CLLocationCoordinate2D?
    let isLoading: Bool
    let errorMessage: String?
    let onSelect: (Destination) -> Void
    let onRetry: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Đang tìm \(category.localizedName.lowercased()) quanh bạn…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        HStack {
                            Button("Đóng") { dismiss() }
                                .buttonStyle(.bordered)
                            Button("Thử lại") { onRetry() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(24)
                } else if destinations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Không tìm thấy \(category.localizedName.lowercased()) gần đây")
                            .font(.headline)
                        Text("Hãy di chuyển bản đồ hoặc thử lại khi GPS và kết nối mạng ổn định.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Tìm lại") { onRetry() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(destinations) { destination in
                                placeCard(destination)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("\(category.localizedName) · \(destinations.count) địa điểm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(360), .medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func placeCard(_ destination: Destination) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: category.systemImage)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 42, height: 42)
                    .background(Color.blue.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    if let address = destination.formattedAddress {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let distance = distanceText(to: destination) {
                        Label(distance, systemImage: "location.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        onSelect(destination)
                        dismiss()
                    } label: {
                        Label("Đường đi", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    if let phoneNumber = destination.phoneNumber,
                       let phoneURL = phoneURL(phoneNumber) {
                        Button {
                            UIApplication.shared.open(phoneURL)
                        } label: {
                            Label("Gọi", systemImage: "phone.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    if let websiteURL = destination.websiteURL {
                        Link(destination: websiteURL) {
                            Label("Trang web", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }

                    ShareLink(item: shareText(for: destination)) {
                        Label("Chia sẻ", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func distanceText(to destination: Destination) -> String? {
        guard let userCoordinate else { return nil }
        let origin = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let target = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return DistanceFormatter.string(fromMeters: origin.distance(from: target))
    }

    private func phoneURL(_ phoneNumber: String) -> URL? {
        let allowed = phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard !allowed.isEmpty else { return nil }
        return URL(string: "tel:\(allowed)")
    }

    private func shareText(for destination: Destination) -> String {
        var values = [destination.displayName]
        if let address = destination.formattedAddress { values.append(address) }
        values.append(
            "https://maps.apple.com/?ll=\(destination.latitude),\(destination.longitude)&q=\(destination.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination.displayName)"
        )
        return values.joined(separator: "\n")
    }
}
