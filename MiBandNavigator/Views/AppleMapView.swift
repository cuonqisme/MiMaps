import MapKit
import SwiftUI

struct AppleMapView: UIViewRepresentable {
    let destination: Destination?
    let nearbyDestinations: [Destination]
    @ObservedObject var navigationProvider: AppleNavigationProvider
    let displayStyle: MapDisplayStyle
    let recenterRequest: Int
    let onUserLocationChange: (CLLocationCoordinate2D) -> Void
    let onDestinationSelected: (Destination) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onUserLocationChange: onUserLocationChange,
            onDestinationSelected: onDestinationSelected
        )
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.showsCompass = true
        mapView.showsUserLocation = true
        mapView.selectableMapFeatures = [.pointsOfInterest]
        mapView.mapType = displayStyle.mapType
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        mapView.addGestureRecognizer(longPress)
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
        context.coordinator.onDestinationSelected = onDestinationSelected
        if mapView.mapType != displayStyle.mapType {
            mapView.mapType = displayStyle.mapType
        }

        if context.coordinator.recenterRequest != recenterRequest {
            context.coordinator.recenterRequest = recenterRequest
            mapView.setUserTrackingMode(.followWithHeading, animated: true)
        }

        let annotationIDs = Set(nearbyDestinations.map(\.id) + [destination?.id].compactMap { $0 })
        if context.coordinator.annotationIDs != annotationIDs {
            context.coordinator.annotationIDs = annotationIDs
            let removable = mapView.annotations.compactMap { $0 as? DestinationMapAnnotation }
            mapView.removeAnnotations(removable)
            if let destination {
                let annotation = DestinationMapAnnotation(destination: destination, isPrimary: true)
                mapView.addAnnotation(annotation)
                mapView.setCenter(annotation.coordinate, animated: true)
            }
            mapView.addAnnotations(
                nearbyDestinations
                    .filter { $0.id != destination?.id }
                    .map { DestinationMapAnnotation(destination: $0, isPrimary: false) }
            )
        }

        if context.coordinator.routeRevision != navigationProvider.routeRevision {
            context.coordinator.routeRevision = navigationProvider.routeRevision
            mapView.removeOverlays(mapView.overlays)
            context.coordinator.selectedPolyline = navigationProvider.routePolyline
            if let polyline = navigationProvider.routePolyline {
                let alternatePolylines = navigationProvider.routePolylines.filter { $0 !== polyline }
                mapView.addOverlays(alternatePolylines)
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
        var annotationIDs: Set<UUID> = []
        var routeRevision = -1
        var recenterRequest = 0
        var hasCenteredInitialLocation = false
        var selectedPolyline: MKPolyline?
        var onUserLocationChange: (CLLocationCoordinate2D) -> Void
        var onDestinationSelected: (Destination) -> Void

        init(
            onUserLocationChange: @escaping (CLLocationCoordinate2D) -> Void,
            onDestinationSelected: @escaping (Destination) -> Void
        ) {
            self.onUserLocationChange = onUserLocationChange
            self.onDestinationSelected = onDestinationSelected
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            let coordinate = mapView.convert(gesture.location(in: mapView), toCoordinateFrom: mapView)
            onDestinationSelected(
                Destination(
                    displayName: "Vị trí đã ghim",
                    formattedAddress: String(
                        format: "%.6f, %.6f",
                        locale: Locale(identifier: "en_US_POSIX"),
                        coordinate.latitude,
                        coordinate.longitude
                    ),
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
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
            let isSelected = polyline === selectedPolyline
            renderer.strokeColor = isSelected ? .systemBlue : .systemGray.withAlphaComponent(0.75)
            renderer.lineWidth = isSelected ? 7 : 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            _ = mapView
            guard let destinationAnnotation = annotation as? DestinationMapAnnotation else { return nil }
            let identifier = destinationAnnotation.isPrimary ? "destination" : "nearby"
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.markerTintColor = destinationAnnotation.isPrimary ? .systemBlue : .systemOrange
            view.glyphImage = UIImage(
                systemName: destinationAnnotation.isPrimary ? "flag.fill" : "mappin"
            )
            view.canShowCallout = true
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            _ = mapView
            if let annotation = view.annotation as? DestinationMapAnnotation {
                onDestinationSelected(annotation.destination)
                return
            }
            guard let feature = view.annotation as? MKMapFeatureAnnotation else { return }
            let request = MKMapItemRequest(mapFeatureAnnotation: feature)
            request.getMapItem { [weak self] item, _ in
                guard let item else { return }
                Task { @MainActor [weak self] in
                    self?.select(item)
                }
            }
        }

        private func select(_ item: MKMapItem) {
            let coordinate: CLLocationCoordinate2D
            let address: String?
            if #available(iOS 26.0, *) {
                coordinate = item.location.coordinate
                address = item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
                    ?? item.address?.fullAddress
            } else {
                coordinate = item.placemark.coordinate
                address = item.placemark.title
            }
            guard CLLocationCoordinate2DIsValid(coordinate) else { return }
            onDestinationSelected(
                Destination(
                    displayName: item.name ?? "Điểm trên bản đồ",
                    formattedAddress: address,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
        }
    }
}

private final class DestinationMapAnnotation: MKPointAnnotation {
    let destination: Destination
    let isPrimary: Bool

    init(destination: Destination, isPrimary: Bool) {
        self.destination = destination
        self.isPrimary = isPrimary
        super.init()
        title = destination.displayName
        subtitle = destination.formattedAddress
        coordinate = CLLocationCoordinate2D(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
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
