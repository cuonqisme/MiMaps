import SwiftUI

struct MapScreen: View {
    let environment: AppEnvironment
    @ObservedObject private var googleProvider: GoogleNavigationProvider
    @ObservedObject private var googleCoordinator: NavigationCoordinator
    @ObservedObject private var locationPermissionManager: LocationPermissionManager
    @ObservedObject private var settings: AppSettings
    @State private var selectedDestination: Destination?
    @State private var isSearchPresented = false
    @State private var routeError: String?

    init(environment: AppEnvironment) {
        self.environment = environment
        _googleProvider = ObservedObject(wrappedValue: environment.googleNavigationProvider)
        _googleCoordinator = ObservedObject(wrappedValue: environment.googleNavigationCoordinator)
        _locationPermissionManager = ObservedObject(wrappedValue: environment.locationPermissionManager)
        _settings = ObservedObject(wrappedValue: environment.settings)
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapContent
                .ignoresSafeArea(edges: .bottom)

            Group {
                if let instruction = googleCoordinator.currentInstruction,
                   googleCoordinator.state == .navigating
                    || googleCoordinator.state == .rerouting
                    || googleCoordinator.state == .arrived {
                    ManeuverCardView(instruction: instruction)
                } else {
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
                    .accessibilityHint("Mở tìm kiếm địa điểm bằng Google Places")
                }
            }
            .padding()

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
                        routeActions(for: selectedDestination)

                        if googleProvider.fallbackUsed {
                            Label("Xe máy không được hỗ trợ; đang dùng tuyến ô tô.", systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        if let visibleError = routeError ?? googleCoordinator.lastError {
                            Text(visibleError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
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
                if selectedDestination?.id != destination.id,
                   googleCoordinator.state == .routePreview
                    || googleCoordinator.state == .navigating
                    || googleCoordinator.state == .rerouting {
                    googleCoordinator.stopNavigation()
                }
                selectedDestination = destination
                routeError = nil
            }
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        switch AppConfig.googleAPIConfigurationStatus {
        case .configured:
            GoogleMapView(
                destination: selectedDestination,
                navigationProvider: environment.googleNavigationProvider
            )
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

    @ViewBuilder
    private func routeActions(for destination: Destination) -> some View {
        switch googleCoordinator.state {
        case .calculatingRoute, .startingNavigation:
            ProgressView("Đang tính tuyến…")
                .frame(maxWidth: .infinity)
        case .routePreview:
            Button("BẮT ĐẦU CHỈ ĐƯỜNG") {
                Task { await googleCoordinator.startNavigation() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        case .navigating, .rerouting:
            Button("DỪNG CHỈ ĐƯỜNG", role: .destructive) {
                googleCoordinator.stopNavigation()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        default:
            Button("XEM TRƯỚC TUYẾN ĐƯỜNG") {
                Task { await calculateRoute(to: destination) }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }

    private func calculateRoute(to destination: Destination) async {
        let permission = await locationPermissionManager.requestWhenInUse()
        guard permission.isAuthorized else {
            routeError = "Cần cho phép vị trí để tính tuyến. Trạng thái: \(permission.localizedDescription)."
            return
        }
        routeError = nil
        await googleCoordinator.calculateRoute(to: destination, travelMode: settings.travelMode)
        routeError = googleCoordinator.lastError
    }
}
