import SwiftUI
import UIKit

struct MapScreen: View {
    let environment: AppEnvironment
    @ObservedObject private var navigationProvider: AppleNavigationProvider
    @ObservedObject private var navigationCoordinator: NavigationCoordinator
    @ObservedObject private var locationPermissionManager: LocationPermissionManager
    @ObservedObject private var settings: AppSettings
    @State private var selectedDestination: Destination?
    @State private var isSearchPresented = false
    @State private var routeError: String?
    @State private var navigationWarning: String?
    @State private var shouldOfferSettings = false
    @State private var recenterRequest = 0

    init(environment: AppEnvironment) {
        self.environment = environment
        _navigationProvider = ObservedObject(wrappedValue: environment.liveNavigationProvider)
        _navigationCoordinator = ObservedObject(wrappedValue: environment.liveNavigationCoordinator)
        _locationPermissionManager = ObservedObject(wrappedValue: environment.locationPermissionManager)
        _settings = ObservedObject(wrappedValue: environment.settings)
    }

    var body: some View {
        AppleMapView(
            destination: selectedDestination,
            navigationProvider: navigationProvider,
            displayStyle: settings.mapDisplayStyle,
            recenterRequest: recenterRequest,
            onUserLocationChange: { coordinate in
                environment.placesSearchService.updateSearchCenter(coordinate)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            topCard
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if let selectedDestination {
                destinationCard(selectedDestination)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .overlay(alignment: .topTrailing) {
            mapControls
                .padding(.trailing, 16)
                .padding(.top, controlsTopPadding)
        }
        .navigationTitle("MiBand Navigator")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isSearchPresented) {
            DestinationSearchView(
                searchService: environment.placesSearchService,
                sharedLocationImporter: environment.sharedLocationImporter
            ) { destination in
                if selectedDestination?.id != destination.id,
                   navigationCoordinator.state == .routePreview
                    || navigationCoordinator.state == .navigating
                    || navigationCoordinator.state == .rerouting {
                    navigationCoordinator.stopNavigation()
                }
                selectedDestination = destination
                routeError = nil
                navigationWarning = nil
            }
        }
    }

    private var controlsTopPadding: CGFloat {
        isActivelyNavigating ? 184 : 76
    }

    private var isActivelyNavigating: Bool {
        navigationCoordinator.state == .navigating
            || navigationCoordinator.state == .rerouting
            || navigationCoordinator.state == .arrived
    }

    private var mapControls: some View {
        VStack(spacing: 10) {
            Menu {
                ForEach(MapDisplayStyle.allCases) { style in
                    Button {
                        settings.mapDisplayStyle = style
                    } label: {
                        Label(
                            style.localizedName,
                            systemImage: settings.mapDisplayStyle == style
                                ? "checkmark.circle.fill"
                                : style.systemImage
                        )
                    }
                }
            } label: {
                mapControlIcon(settings.mapDisplayStyle.systemImage)
            }
            .accessibilityLabel("Chọn kiểu bản đồ")

            Button {
                recenterRequest += 1
            } label: {
                mapControlIcon("location.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Về vị trí hiện tại")

            if let speed = navigationProvider.lastSpeedMetersPerSecond,
               isActivelyNavigating {
                VStack(spacing: 0) {
                    Text("\(Int((speed * 3.6).rounded()))")
                        .font(.headline.monospacedDigit())
                    Text("km/h")
                        .font(.caption2)
                }
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .accessibilityLabel("Tốc độ hiện tại \(Int((speed * 3.6).rounded())) ki-lô-mét một giờ")
            }
        }
    }

    private func mapControlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 52, height: 52)
            .background(.regularMaterial, in: Circle())
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    @ViewBuilder
    private var topCard: some View {
        if let instruction = navigationCoordinator.currentInstruction,
           navigationCoordinator.state == .navigating
            || navigationCoordinator.state == .rerouting
            || navigationCoordinator.state == .arrived {
            ManeuverCardView(instruction: instruction)
        } else {
            Button { isSearchPresented = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                    Text("Tìm điểm đến…")
                    Spacer()
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Mở tìm kiếm địa điểm bằng Apple Maps")
        }
    }

    private func destinationCard(_ destination: Destination) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    if let address = destination.formattedAddress {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                Button {
                    navigationCoordinator.stopNavigation()
                    selectedDestination = nil
                    routeError = nil
                    navigationWarning = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Đóng điểm đến")
            }

            routeActions(for: destination)

            if navigationProvider.fallbackUsed {
                Label(
                    "Apple Maps chưa có tuyến xe máy; đang dùng tuyến ô tô.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
            if let visibleError = routeError ?? navigationCoordinator.lastError {
                Text(visibleError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if let navigationWarning {
                Label(navigationWarning, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if shouldOfferSettings {
                Button("Mở Cài đặt iOS") { openSystemSettings() }
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
    }

    @ViewBuilder
    private func routeActions(for destination: Destination) -> some View {
        switch navigationCoordinator.state {
        case .calculatingRoute, .startingNavigation:
            ProgressView("Đang tính tuyến…")
                .frame(maxWidth: .infinity)
        case .routePreview:
            Button("BẮT ĐẦU CHỈ ĐƯỜNG") {
                Task { await startNavigation() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        case .navigating, .rerouting:
            Button("DỪNG CHỈ ĐƯỜNG", role: .destructive) {
                navigationCoordinator.stopNavigation()
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
            shouldOfferSettings = true
            return
        }
        routeError = nil
        shouldOfferSettings = false
        await navigationCoordinator.calculateRoute(to: destination, travelMode: settings.travelMode)
        routeError = navigationCoordinator.lastError
    }

    private func startNavigation() async {
        let result = await environment.navigationPermissionPreflight.prepare(
            notificationsRequired: settings.bandNotificationsEnabled
        )
        navigationWarning = result.warning
        shouldOfferSettings = result.shouldOfferSettings
        guard result.canStartNavigation else {
            routeError = result.warning
            return
        }

        routeError = nil
        await navigationCoordinator.startNavigation()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
