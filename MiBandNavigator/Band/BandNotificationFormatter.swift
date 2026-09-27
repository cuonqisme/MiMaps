import Foundation

struct ManeuverSymbolConfiguration: Sendable, Equatable {
    var overrides: [ManeuverSymbolKey: String]

    init(overrides: [ManeuverSymbolKey: String] = [:]) {
        self.overrides = overrides
    }
}

struct BandNotificationFormatter: Sendable {
    let symbols: ManeuverSymbolConfiguration

    init(symbols: ManeuverSymbolConfiguration = ManeuverSymbolConfiguration()) {
        self.symbols = symbols
    }

    func format(
        _ instruction: NavigationInstruction,
        soundEnabled: Bool = false
    ) -> NavigationNotificationContent {
        let symbol = symbol(for: instruction.maneuver)
        if instruction.maneuver == .destination {
            return NavigationNotificationContent(
                title: "\(symbol) Đã đến nơi",
                body: normalizedRoadName(instruction.roadName) ?? "MiBand Navigator",
                categoryIdentifier: LocalNotificationService.navigationCategoryIdentifier,
                soundEnabled: soundEnabled
            )
        }

        return NavigationNotificationContent(
            title: "\(symbol) \(DistanceFormatter.string(fromMeters: instruction.distanceToManeuverMeters))",
            body: body(for: instruction),
            categoryIdentifier: LocalNotificationService.navigationCategoryIdentifier,
            soundEnabled: soundEnabled
        )
    }

    func symbol(for maneuver: NavigationManeuver) -> String {
        if let override = symbols.overrides[maneuver.symbolKey], !override.isEmpty {
            return override
        }

        return switch maneuver {
        case .straight: "^"
        case .slightLeft: "^<"
        case .left: "<"
        case .sharpLeft: "<<"
        case .slightRight: "^>"
        case .right: ">"
        case .sharpRight: ">>"
        case .uTurnLeft: "U<"
        case .uTurnRight: "U>"
        case .mergeLeft, .forkLeft, .rampLeft: "^<"
        case .mergeRight, .forkRight, .rampRight: "^>"
        case .roundabout, .roundaboutExit: "O"
        case .destination: "*"
        case .unknown: "^"
        }
    }

    private func body(for instruction: NavigationInstruction) -> String {
        let roadName = normalizedRoadName(instruction.roadName)
        if case let .roundaboutExit(exit) = instruction.maneuver, let exit {
            return roadName.map { "Lối ra \(exit) • \($0)" } ?? "Lối ra \(exit)"
        }
        return roadName ?? "Tiếp tục theo tuyến đường"
    }

    private func normalizedRoadName(_ roadName: String?) -> String? {
        guard let value = roadName?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
