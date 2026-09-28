import XCTest
@testable import MiMaps

final class FormatterTests: XCTestCase {
    func testDistanceUnderOneKilometer() {
        XCTAssertEqual(DistanceFormatter.string(fromMeters: 120), "120 m")
        XCTAssertEqual(DistanceFormatter.string(fromMeters: 999), "999 m")
    }

    func testDistanceAtOrOverOneKilometer() {
        XCTAssertEqual(DistanceFormatter.string(fromMeters: 1_000), "1 km")
        XCTAssertEqual(DistanceFormatter.string(fromMeters: 1_240), "1.2 km")
        XCTAssertEqual(DistanceFormatter.string(fromMeters: 2_000), "2 km")
    }

    func testDurationFormatting() {
        XCTAssertEqual(DurationFormatter.string(fromSeconds: 30), "<1 phút")
        XCTAssertEqual(DurationFormatter.string(fromSeconds: 12 * 60), "12 phút")
        XCTAssertEqual(DurationFormatter.string(fromSeconds: 75 * 60), "1 giờ 15 phút")
    }

    func testBandFormatterMapsManeuversAndRoad() {
        let formatter = BandNotificationFormatter()
        let instruction = makeInstruction(maneuver: .sharpRight, roadName: "Trần Phú", distance: 120)

        let content = formatter.format(instruction)

        XCTAssertEqual(content.title, "→ 120 m")
        XCTAssertEqual(content.body, "Rẽ gấp phải · Trần Phú")
        XCTAssertFalse(content.soundEnabled)
    }

    func testBandFormatterHandlesRoundaboutExit() {
        let formatter = BandNotificationFormatter()
        let content = formatter.format(
            makeInstruction(maneuver: .roundaboutExit(2), roadName: nil, distance: 200)
        )

        XCTAssertEqual(content.title, "↑ 200 m")
        XCTAssertEqual(content.body, "Vòng xuyến · lối ra 2")
    }

    func testBandFormatterHandlesUTurnUnknownAndMissingRoad() {
        let formatter = BandNotificationFormatter()

        XCTAssertEqual(formatter.symbol(for: .uTurnLeft), "←")
        XCTAssertEqual(formatter.symbol(for: .uTurnRight), "→")
        XCTAssertEqual(formatter.symbol(for: .sharpLeft), "←")
        XCTAssertEqual(formatter.symbol(for: .sharpRight), "→")
        XCTAssertEqual(formatter.symbol(for: .roundabout), "↑")
        XCTAssertEqual(formatter.symbol(for: .unknown), "↑")
        XCTAssertEqual(
            formatter.format(makeInstruction(maneuver: .uTurnLeft, roadName: "Trần Phú", distance: 80)).body,
            "Quay đầu trái · Trần Phú"
        )
        XCTAssertEqual(
            formatter.format(makeInstruction(maneuver: .unknown, roadName: " ", distance: 80)).body,
            "Tiếp tục theo tuyến"
        )
    }

    func testBandFormatterSupportsSymbolOverridesAndDestination() {
        let formatter = BandNotificationFormatter(
            symbols: ManeuverSymbolConfiguration(overrides: [.roundabout: "O", .sharpRight: "→"])
        )

        XCTAssertEqual(formatter.symbol(for: .roundabout), "O")
        XCTAssertEqual(formatter.symbol(for: .roundaboutExit(3)), "O")
        XCTAssertEqual(formatter.symbol(for: .sharpRight), "→")
        XCTAssertEqual(
            formatter.format(makeInstruction(maneuver: .destination, roadName: nil, distance: 0)).title,
            "● Đã đến nơi"
        )
    }

    func testBandFormatterOmitsSpeedFromTurnInstruction() {
        let instruction = NavigationInstruction(
            maneuver: .right,
            roadName: "Trần Phú",
            distanceToManeuverMeters: 200,
            remainingDistanceMeters: 2_000,
            remainingTimeSeconds: 300,
            stepIdentifier: "speed",
            currentSpeedKPH: 41.6
        )

        XCTAssertEqual(
            BandNotificationFormatter().format(instruction).body,
            "Rẽ phải · Trần Phú"
        )
    }

    func testBandFormatterIncludesAvailableSpeedLimitWhenEnabled() {
        let instruction = NavigationInstruction(
            maneuver: .right,
            roadName: "Trần Phú",
            distanceToManeuverMeters: 143,
            remainingDistanceMeters: 2_000,
            remainingTimeSeconds: 300,
            stepIdentifier: "limit",
            currentSpeedKPH: 41.6,
            speedLimitKPH: 60
        )

        XCTAssertEqual(
            BandNotificationFormatter().format(instruction).body,
            "Rẽ phải · Trần Phú · Giới hạn 60 km/h"
        )
        XCTAssertEqual(
            BandNotificationFormatter().format(instruction, includeSpeedLimit: false).body,
            "Rẽ phải · Trần Phú"
        )
    }

    func testBandFormatterFormatsSafetyCameraAlert() {
        let instruction = NavigationInstruction(
            maneuver: .straight,
            roadName: nil,
            distanceToManeuverMeters: 0,
            remainingDistanceMeters: 2_000,
            remainingTimeSeconds: 300,
            stepIdentifier: "camera",
            currentSpeedKPH: 55,
            speedLimitKPH: 60,
            safetyAlert: NavigationSafetyAlert(
                identifier: "camera-1",
                kind: .fixedSpeedCamera,
                distanceMeters: 450,
                speedLimitKPH: 60
            )
        )

        let content = BandNotificationFormatter().format(instruction)

        XCTAssertEqual(content.title, "● Camera tốc độ 450 m")
        XCTAssertEqual(content.body, "Giới hạn 60 km/h")
        XCTAssertEqual(
            BandNotificationFormatter().format(instruction, includeSpeedLimit: false).body,
            "Chú ý phía trước"
        )
    }
}

private func makeInstruction(
    maneuver: NavigationManeuver,
    roadName: String? = "Đường thử nghiệm",
    distance: Double,
    step: String = "step-1",
    timestamp: Date = Date(timeIntervalSince1970: 1_000)
) -> NavigationInstruction {
    NavigationInstruction(
        maneuver: maneuver,
        roadName: roadName,
        distanceToManeuverMeters: distance,
        remainingDistanceMeters: 5_000,
        remainingTimeSeconds: 600,
        stepIdentifier: step,
        timestamp: timestamp
    )
}
