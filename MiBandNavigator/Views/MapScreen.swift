import SwiftUI

struct MapScreen: View {
    let environment: AppEnvironment
    @State private var selectedDestination: Destination?
    @State private var isSearchPresented = false

    var body: some View {
        ZStack(alignment: .top) {
            mapContent
                .ignoresSafeArea(edges: .bottom)

            Button { isSearchPresented = true } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Tìm điểm đến…")
                    Spacer()
                }
                .foregroundStyle(.primary)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .shadow(radius: 4, y: 2)
            }
            .padding()
            .accessibilityHint("Mở tìm kiếm địa điểm bằng Google Places")

            if let selectedDestination {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedDestination.displayName)
                            .font(.headline)
                        if let address = selectedDestination.formattedAddress {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Button("XEM TRƯỚC TUYẾN ĐƯỜNG") {}
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding()
                }
            }
        }
        .navigationTitle("MiBand Navigator")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isSearchPresented) {
            DestinationSearchView(searchService: environment.placesSearchService) { destination in
                selectedDestination = destination
            }
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        switch AppConfig.googleAPIConfigurationStatus {
        case .configured:
            GoogleMapView(destination: selectedDestination)
        case .missing:
            VStack(spacing: 16) {
                Image(systemName: "map.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Chưa cấu hình Google Maps")
                    .font(.title2.bold())
                Text("Thêm GOOGLE_MAPS_API_KEY vào Configuration/Secrets.xcconfig hoặc GitHub Actions secret để tải bản đồ.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
        }
    }
}
