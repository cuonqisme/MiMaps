import GoogleMaps
import SwiftUI

struct GoogleMapView: UIViewRepresentable {
    private let latitude: CLLocationDegrees
    private let longitude: CLLocationDegrees
    private let zoom: Float

    init(latitude: CLLocationDegrees = 21.0285, longitude: CLLocationDegrees = 105.8542, zoom: Float = 13) {
        self.latitude = latitude
        self.longitude = longitude
        self.zoom = zoom
    }

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition(latitude: latitude, longitude: longitude, zoom: zoom)
        let mapView = GMSMapView(options: options)
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = true
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.overrideUserInterfaceStyle = context.environment.colorScheme == .dark ? .dark : .light
    }
}

