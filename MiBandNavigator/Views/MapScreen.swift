import SwiftUI

struct MapScreen: View {
    var body: some View {
        ZStack(alignment: .top) {
            mapContent
                .ignoresSafeArea(edges: .bottom)

            Button(action: {}) {
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
            .accessibilityHint("Tìm địa điểm bằng Google Places sẽ được bật ở mốc tiếp theo")
        }
        .navigationTitle("MiBand Navigator")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var mapContent: some View {
        switch AppConfig.googleAPIConfigurationStatus {
        case .configured:
            GoogleMapView()
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
