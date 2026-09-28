import CoreLocation
import XCTest
@testable import MiMaps

final class RouteGeometryTests: XCTestCase {
    func testProjectionUsesSegmentsInsteadOfOnlySparseVertices() throws {
        let geometry = try XCTUnwrap(
            RouteGeometry(coordinates: [coordinate(0, 0), coordinate(0, 0.1)])
        )

        let projection = try XCTUnwrap(
            geometry.project(
                coordinate: coordinate(0.000_1, 0.05),
                previousProgressMeters: nil,
                elapsedTime: 1,
                speedMetersPerSecond: 15,
                horizontalAccuracy: 5,
                courseDegrees: 90
            )
        )

        XCTAssertLessThan(projection.distanceFromRouteMeters, 15)
        XCTAssertEqual(projection.progressMeters, geometry.totalDistanceMeters / 2, accuracy: 20)
    }

    func testCourseDisambiguatesOppositeParallelRouteLegs() throws {
        let geometry = try XCTUnwrap(
            RouteGeometry(
                coordinates: [
                    coordinate(0, 0),
                    coordinate(0, 0.01),
                    coordinate(0.000_01, 0.01),
                    coordinate(0.000_01, 0)
                ]
            )
        )
        let location = coordinate(0.000_005, 0.005)

        let eastbound = try XCTUnwrap(
            geometry.project(
                coordinate: location,
                previousProgressMeters: nil,
                elapsedTime: 1,
                speedMetersPerSecond: 12,
                horizontalAccuracy: 5,
                courseDegrees: 90
            )
        )
        let westbound = try XCTUnwrap(
            geometry.project(
                coordinate: location,
                previousProgressMeters: nil,
                elapsedTime: 1,
                speedMetersPerSecond: 12,
                horizontalAccuracy: 5,
                courseDegrees: 270
            )
        )

        XCTAssertLessThan(eastbound.progressMeters, geometry.totalDistanceMeters / 2)
        XCTAssertGreaterThan(westbound.progressMeters, geometry.totalDistanceMeters / 2)
    }

    func testProgressDoesNotRegressFromOrdinaryGPSJitter() throws {
        let geometry = try XCTUnwrap(
            RouteGeometry(coordinates: [coordinate(0, 0), coordinate(0, 0.01)])
        )
        let projection = try XCTUnwrap(
            geometry.project(
                coordinate: coordinate(0, 0.004),
                previousProgressMeters: 500,
                elapsedTime: 1,
                speedMetersPerSecond: 10,
                horizontalAccuracy: 5,
                courseDegrees: 90
            )
        )

        XCTAssertGreaterThanOrEqual(projection.progressMeters, 500)
    }

    func testSignedTurnAngleUsesRightPositiveAndLeftNegative() throws {
        let right = try XCTUnwrap(
            RouteGeometry.signedTurnAngleDegrees(
                incomingStart: coordinate(0, 0),
                incomingEnd: coordinate(0.001, 0),
                outgoingStart: coordinate(0.001, 0),
                outgoingEnd: coordinate(0.001, 0.001)
            )
        )
        let left = try XCTUnwrap(
            RouteGeometry.signedTurnAngleDegrees(
                incomingStart: coordinate(0, 0),
                incomingEnd: coordinate(0.001, 0),
                outgoingStart: coordinate(0.001, 0),
                outgoingEnd: coordinate(0.001, -0.001)
            )
        )

        XCTAssertEqual(right, 90, accuracy: 1)
        XCTAssertEqual(left, -90, accuracy: 1)
    }

    private func coordinate(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
