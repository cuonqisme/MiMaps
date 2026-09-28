@preconcurrency import CoreLocation
import Foundation

struct RouteProjection: Equatable, Sendable {
    let progressMeters: CLLocationDistance
    let distanceFromRouteMeters: CLLocationDistance
    let routeBearingDegrees: CLLocationDirection
    let headingDifferenceDegrees: CLLocationDirection?
}

struct RouteGeometry {
    private struct Point {
        let x: Double
        let y: Double
    }

    private struct Candidate {
        let progress: Double
        let crossTrackDistance: Double
        let bearing: Double
        let headingDifference: Double?
        let score: Double
    }

    private static let earthRadiusMeters = 6_371_000.0

    let coordinates: [CLLocationCoordinate2D]
    let totalDistanceMeters: CLLocationDistance

    private let referenceLatitudeRadians: Double
    private let points: [Point]
    private let cumulativeDistances: [Double]

    init?(coordinates: [CLLocationCoordinate2D]) {
        let valid = coordinates.filter { CLLocationCoordinate2DIsValid($0) }
        guard valid.count >= 2 else { return nil }

        self.coordinates = valid
        let referenceLatitude = valid.map(\.latitude).reduce(0, +)
            / Double(valid.count) * .pi / 180
        referenceLatitudeRadians = referenceLatitude
        let cartesianPoints = valid.map {
            Point(
                x: $0.longitude * .pi / 180
                    * Self.earthRadiusMeters * cos(referenceLatitude),
                y: $0.latitude * .pi / 180 * Self.earthRadiusMeters
            )
        }
        points = cartesianPoints

        var cumulative = [0.0]
        cumulative.reserveCapacity(cartesianPoints.count)
        for index in 0..<(cartesianPoints.count - 1) {
            cumulative.append(
                cumulative[index] + Self.distance(cartesianPoints[index], cartesianPoints[index + 1])
            )
        }
        guard let total = cumulative.last, total > 0 else { return nil }
        cumulativeDistances = cumulative
        totalDistanceMeters = total
    }

    func project(
        coordinate: CLLocationCoordinate2D,
        previousProgressMeters: CLLocationDistance?,
        elapsedTime: TimeInterval,
        speedMetersPerSecond: CLLocationSpeed?,
        horizontalAccuracy: CLLocationAccuracy,
        courseDegrees: CLLocationDirection?
    ) -> RouteProjection? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let query = point(for: coordinate)
        let validCourse = courseDegrees.flatMap { (0..<360).contains($0) ? $0 : nil }
        let speed = max(0, speedMetersPerSecond ?? 0)
        let accuracy = max(0, horizontalAccuracy)
        let time = max(1, elapsedTime)
        let maximumForwardProgress = previousProgressMeters.map {
            $0 + max(250, speed * time * 3 + accuracy * 3 + 100)
        }
        let minimumProgress = previousProgressMeters.map { max(0, $0 - 35) }

        var best: Candidate?
        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let dx = end.x - start.x
            let dy = end.y - start.y
            let squaredLength = dx * dx + dy * dy
            guard squaredLength > 0 else { continue }

            let rawT = ((query.x - start.x) * dx + (query.y - start.y) * dy) / squaredLength
            let t = min(1, max(0, rawT))
            let projected = Point(x: start.x + t * dx, y: start.y + t * dy)
            let crossTrack = Self.distance(query, projected)
            let segmentLength = sqrt(squaredLength)
            let progress = cumulativeDistances[index] + segmentLength * t
            let bearing = Self.normalizedBearing(atan2(dx, dy) * 180 / .pi)
            let headingDifference = validCourse.map { Self.angularDifference($0, bearing) }

            var score = crossTrack
            if speed >= 2, let headingDifference {
                score += headingDifference * 0.45
            }
            if let minimumProgress, progress < minimumProgress {
                score += 2_000 + (minimumProgress - progress) * 10
            }
            if let maximumForwardProgress, progress > maximumForwardProgress {
                score += 2_000 + (progress - maximumForwardProgress) * 5
            }

            let candidate = Candidate(
                progress: progress,
                crossTrackDistance: crossTrack,
                bearing: bearing,
                headingDifference: headingDifference,
                score: score
            )
            if best == nil || candidate.score < best!.score { best = candidate }
        }

        guard let best else { return nil }
        let progress: Double
        if let previousProgressMeters,
           best.crossTrackDistance <= max(80, accuracy * 3) {
            progress = max(previousProgressMeters, best.progress)
        } else {
            progress = best.progress
        }
        return RouteProjection(
            progressMeters: min(totalDistanceMeters, max(0, progress)),
            distanceFromRouteMeters: best.crossTrackDistance,
            routeBearingDegrees: best.bearing,
            headingDifferenceDegrees: best.headingDifference
        )
    }

    static func signedTurnAngleDegrees(
        incomingStart: CLLocationCoordinate2D,
        incomingEnd: CLLocationCoordinate2D,
        outgoingStart: CLLocationCoordinate2D,
        outgoingEnd: CLLocationCoordinate2D
    ) -> Double? {
        guard let incoming = bearingDegrees(from: incomingStart, to: incomingEnd),
              let outgoing = bearingDegrees(from: outgoingStart, to: outgoingEnd) else { return nil }
        var delta = outgoing - incoming
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    static func bearingDegrees(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> Double? {
        guard CLLocationCoordinate2DIsValid(start), CLLocationCoordinate2DIsValid(end) else { return nil }
        let latitude = ((start.latitude + end.latitude) / 2) * .pi / 180
        let dx = (end.longitude - start.longitude) * cos(latitude)
        let dy = end.latitude - start.latitude
        guard abs(dx) + abs(dy) > 0.000_000_001 else { return nil }
        return normalizedBearing(atan2(dx, dy) * 180 / .pi)
    }

    private func point(for coordinate: CLLocationCoordinate2D) -> Point {
        Point(
            x: coordinate.longitude * .pi / 180
                * Self.earthRadiusMeters * cos(referenceLatitudeRadians),
            y: coordinate.latitude * .pi / 180 * Self.earthRadiusMeters
        )
    }

    private static func distance(_ lhs: Point, _ rhs: Point) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private static func normalizedBearing(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360)
        return result >= 0 ? result : result + 360
    }

    private static func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        let difference = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }
}
