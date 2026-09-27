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
        if let alert = instruction.safetyAlert {
            return safetyContent(
                alert,
                instruction: instruction,
                soundEnabled: soundEnabled
            )
        }
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
            body: bodyWithSpeed(for: instruction),
            categoryIdentifier: LocalNotificationService.navigationCategoryIdentifier,
            soundEnabled: soundEnabled
        )
    }

    private func safetyContent(
        _ alert: NavigationSafetyAlert,
        instruction: NavigationInstruction,
        soundEnabled: Bool
    ) -> NavigationNotificationContent {
        var details: [String] = []
        if let limit = alert.speedLimitKPH ?? instruction.speedLimitKPH {
            details.append("Giới hạn \(Int(limit.rounded())) km/h")
        }
        if let speed = instruction.currentSpeedKPH {
            details.append("Đang đi \(Int(speed.rounded())) km/h")
        }
        return NavigationNotificationContent(
            title: "● \(alert.kind.localizedName) \(DistanceFormatter.string(fromMeters: alert.distanceMeters))",
            body: details.isEmpty ? "Chú ý phía trước" : details.joined(separator: " • "),
            categoryIdentifier: LocalNotificationService.navigationCategoryIdentifier,
            soundEnabled: soundEnabled
        )
    }

    private func bodyWithSpeed(for instruction: NavigationInstruction) -> String {
        var details = [body(for: instruction)]
        if let limit = instruction.speedLimitKPH {
            details.append("Giới hạn \(Int(limit.rounded())) km/h")
        }
        if let speed = instruction.currentSpeedKPH {
            details.append("Tốc độ \(Int(speed.rounded())) km/h")
        }
        return details.joined(separator: " • ")
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

    private func body(for instruction: NavigationInstruction) -> String {
        let roadName = normalizedRoadName(instruction.roadName)
        if case let .roundaboutExit(exit) = instruction.maneuver, let exit {
            return roadName.map { "Lối ra \(exit) • \($0)" } ?? "Lối ra \(exit)"
        }
        let fallbackLabel: String? = switch instruction.maneuver {
        case .sharpLeft: "Rẽ gấp trái"
        case .sharpRight: "Rẽ gấp phải"
        case .uTurnLeft: "Quay đầu trái"
        case .uTurnRight: "Quay đầu phải"
        case .roundabout: "Vòng xuyến"
        default: nil
        }
        if let fallbackLabel, let roadName {
            return "\(fallbackLabel) • \(roadName)"
        }
        return fallbackLabel ?? roadName ?? "Tiếp tục theo tuyến đường"
    }

    private func normalizedRoadName(_ roadName: String?) -> String? {
        guard let value = roadName?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}
