import MapKit
import SwiftUI

struct AppleMapView: UIViewRepresentable {
    let destination: Destination?
    @ObservedObject var navigationProvider: AppleNavigationProvider
    let displayStyle: MapDisplayStyle
    let recenterRequest: Int
    let onUserLocationChange: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onUserLocationChange: onUserLocationChange)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.showsCompass = true
        mapView.showsUserLocation = true
        mapView.mapType = displayStyle.mapType
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ),
            animated: false
        )
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onUserLocationChange = onUserLocationChange
        if mapView.mapType != displayStyle.mapType {
            mapView.mapType = displayStyle.mapType
        }

        if context.coordinator.recenterRequest != recenterRequest {
            context.coordinator.recenterRequest = recenterRequest
            mapView.setUserTrackingMode(.followWithHeading, animated: true)
        }

        if context.coordinator.destinationID != destination?.id {
            context.coordinator.destinationID = destination?.id
            let removable = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(removable)
            if let destination {
                let annotation = MKPointAnnotation()
                annotation.title = destination.displayName
                annotation.subtitle = destination.formattedAddress
                annotation.coordinate = CLLocationCoordinate2D(
                    latitude: destination.latitude,
                    longitude: destination.longitude
                )
                mapView.addAnnotation(annotation)
                mapView.setCenter(annotation.coordinate, animated: true)
            }
        }

        if context.coordinator.routeRevision != navigationProvider.routeRevision {
            context.coordinator.routeRevision = navigationProvider.routeRevision
            mapView.removeOverlays(mapView.overlays)
            if let polyline = navigationProvider.routePolyline {
                mapView.addOverlay(polyline)
                mapView.setVisibleMapRect(
                    polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 150, left: 40, bottom: 260, right: 40),
                    animated: true
                )
            }
        }

        if navigationProvider.currentState == .navigating
            || navigationProvider.currentState == .rerouting {
            if mapView.userTrackingMode != .followWithHeading {
                mapView.setUserTrackingMode(.followWithHeading, animated: true)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var destinationID: UUID?
        var routeRevision = -1
        var recenterRequest = 0
        var hasCenteredInitialLocation = false
        var onUserLocationChange: (CLLocationCoordinate2D) -> Void

        init(onUserLocationChange: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onUserLocationChange = onUserLocationChange
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let location = userLocation.location,
                  location.horizontalAccuracy >= 0 else { return }
            onUserLocationChange(location.coordinate)
            guard !hasCenteredInitialLocation else { return }
            hasCenteredInitialLocation = true
            mapView.setRegion(
                MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 2_000,
                    longitudinalMeters: 2_000
                ),
                animated: true
            )
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            _ = mapView
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 6
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
    }
}

private extension MapDisplayStyle {
    var mapType: MKMapType {
        switch self {
        case .standard: .standard
        case .muted: .mutedStandard
        case .satellite: .satellite
        case .hybrid: .hybrid
        }
    }
}
