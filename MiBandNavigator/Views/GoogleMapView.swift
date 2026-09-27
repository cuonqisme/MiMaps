import GoogleMaps
import GoogleNavigation
import SwiftUI

struct GoogleMapView: UIViewRepresentable {
    private let latitude: CLLocationDegrees
    private let longitude: CLLocationDegrees
    private let zoom: Float
    private let destination: Destination?
    private let navigationProvider: GoogleNavigationProvider?

    init(
        latitude: CLLocationDegrees = 21.0285,
        longitude: CLLocationDegrees = 105.8542,
        zoom: Float = 13,
        destination: Destination? = nil,
        navigationProvider: GoogleNavigationProvider? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.zoom = zoom
        self.destination = destination
        self.navigationProvider = navigationProvider
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition(latitude: latitude, longitude: longitude, zoom: zoom)
        let mapView = GMSMapView(options: options)
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = true
        navigationProvider?.attach(mapView: mapView)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.overrideUserInterfaceStyle = context.environment.colorScheme == .dark ? .dark : .light
        guard context.coordinator.destinationID != destination?.id else { return }
        context.coordinator.destinationID = destination?.id
        context.coordinator.marker?.map = nil
        guard let destination else {
            context.coordinator.marker = nil
            return
        }

        let coordinate = CLLocationCoordinate2D(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        let marker = GMSMarker(position: coordinate)
        marker.title = destination.displayName
        marker.snippet = destination.formattedAddress
        marker.map = mapView
        context.coordinator.marker = marker
        mapView.animate(with: GMSCameraUpdate.setTarget(coordinate, zoom: 15))
    }

    final class Coordinator {
        var marker: GMSMarker?
        var destinationID: UUID?
    }
}
