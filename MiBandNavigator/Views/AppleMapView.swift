import MapKit
import SwiftUI

struct AppleMapView: UIViewRepresentable {
    let destination: Destination?
    @ObservedObject var navigationProvider: AppleNavigationProvider

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.showsCompass = true
        mapView.showsUserLocation = true
        if #available(iOS 17.0, *) {
            mapView.showsUserTrackingButton = true
        }
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
