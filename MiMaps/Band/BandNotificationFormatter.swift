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
        soundEnabled: Bool = false,
        includeSpeedLimit: Bool = true
    ) -> NavigationNotificationContent {
        if let alert = instruction.safetyAlert {
            return safetyContent(
                alert,
                instruction: instruction,
                soundEnabled: soundEnabled,
                includeSpeedLimit: includeSpeedLimit
            )
        }
        let symbol = symbol(for: instruction.maneuver)
        if instruction.maneuver == .destination {
            return NavigationNotificationContent(
                title: "\(symbol) Đã đến nơi",
                body: normalizedRoadName(instruction.roadName) ?? "MiMaps",
                categoryIdentifier: LocalNotificationService.navigationCategoryIdentifier,
                soundEnabled: soundEnabled
            )
        }

        var body = instruction.maneuver.conciseInstruction(
            roadName: normalizedRoadName(instruction.roadName)
        )
        if includeSpeedLimit, let limit = instruction.speedLimitKPH {
            body += " · Giới hạn \(Int(limit.rounded())) km/h"
        }
        return NavigationNotificationContent(
            title: "\(symbol) \(DistanceFormatter.string(fromMeters: instruction.distanceToManeuverMeters))",
            body: body,
            categoryIdentifier: LocalNotificationService.navigationCategoryIdentifier,
            soundEnabled: soundEnabled
        )
    }

    private func safetyContent(
        _ alert: NavigationSafetyAlert,
        instruction: NavigationInstruction,
        soundEnabled: Bool,
        includeSpeedLimit: Bool
    ) -> NavigationNotificationContent {
        var details: [String] = []
        if includeSpeedLimit,
           let limit = alert.speedLimitKPH ?? instruction.speedLimitKPH {
            details.append("Giới hạn \(Int(limit.rounded())) km/h")
        }
        return NavigationNotificationContent(
            title: "● \(alert.kind.localizedName) \(DistanceFormatter.string(fromMeters: alert.distanceMeters))",
            body: details.isEmpty ? "Chú ý phía trước" : details.joined(separator: " • "),
            categoryIdentifier: LocalNotificationService.navigationCategoryIdentifier,
            soundEnabled: soundEnabled
        )
    }

    func symbol(for maneuver: NavigationManeuver) -> String {
        if let override = symbols.overrides[maneuver.symbolKey], !override.isEmpty {
            return override
        }

        return switch maneuver {
        case .straight: "↑"
        case .slightLeft: "↖"
        case .left, .sharpLeft, .uTurnLeft: "←"
        case .slightRight: "↗"
        case .right, .sharpRight, .uTurnRight: "→"
        case .mergeLeft, .forkLeft, .rampLeft: "↖"
        case .mergeRight, .forkRight, .rampRight: "↗"
        case .roundabout, .roundaboutExit: "↑"
        case .destination: "●"
        case .unknown: "↑"
        }
    }

    private func normalizedRoadName(_ roadName: String?) -> String? {
        guard let value = roadName?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
