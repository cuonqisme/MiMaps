import Foundation

struct AppleManeuverClassifier: Sendable {
    func classify(
        _ instruction: String,
        turnAngleDegrees: Double? = nil
    ) -> NavigationManeuver {
        let value = normalized(instruction)
        let textManeuver = classifyText(value)

        guard let turnAngleDegrees,
              abs(turnAngleDegrees) >= 15,
              shouldUseGeometry(for: textManeuver, angle: turnAngleDegrees) else {
            return textManeuver
        }
        return classifyGeometry(turnAngleDegrees)
    }

    private func classifyText(_ value: String) -> NavigationManeuver {
        if contains(value, any: ["roundabout", "traffic circle", "vong xuyen", "vong xoay"]) {
            if let exit = roundaboutExitNumber(in: value) {
                return .roundaboutExit(exit)
            }
            return .roundabout
        }
        if contains(value, any: ["u-turn", "u turn", "quay dau"]) {
            return contains(value, any: ["right", "phai"]) ? .uTurnRight : .uTurnLeft
        }
        if contains(value, any: ["sharp left", "gap trai"]) { return .sharpLeft }
        if contains(value, any: ["sharp right", "gap phai"]) { return .sharpRight }
        if contains(
            value,
            any: ["slight left", "keep left", "chech trai", "giu ben trai", "ve ben trai"]
        ) { return .slightLeft }
        if contains(
            value,
            any: ["slight right", "keep right", "chech phai", "giu ben phai", "ve ben phai"]
        ) { return .slightRight }
        if contains(value, any: ["merge left", "nhap lan trai", "nhap vao ben trai"]) { return .mergeLeft }
        if contains(value, any: ["merge right", "nhap lan phai", "nhap vao ben phai"]) { return .mergeRight }
        if contains(value, any: ["fork left", "re nhanh trai"]) { return .forkLeft }
        if contains(value, any: ["fork right", "re nhanh phai"]) { return .forkRight }
        if contains(value, any: ["ramp left", "loi ra ben trai"]) { return .rampLeft }
        if contains(value, any: ["ramp right", "loi ra ben phai"]) { return .rampRight }
        if contains(value, any: ["turn left", "re trai", "sang trai"]) { return .left }
        if contains(value, any: ["turn right", "re phai", "sang phai"]) { return .right }
        if contains(value, any: ["arrive", "destination", "den noi", "diem den"]) { return .destination }
        if contains(value, any: ["continue", "straight", "head ", "di thang", "tiep tuc"]) { return .straight }
        return .unknown
    }

    private func shouldUseGeometry(for maneuver: NavigationManeuver, angle: Double) -> Bool {
        switch maneuver {
        case .roundabout, .roundaboutExit, .destination:
            return false
        case .uTurnLeft, .uTurnRight:
            return abs(angle) >= 135
        case .left, .sharpLeft, .slightLeft, .mergeLeft, .forkLeft, .rampLeft:
            return angle >= 25
        case .right, .sharpRight, .slightRight, .mergeRight, .forkRight, .rampRight:
            return angle <= -25
        case .straight, .unknown:
            return true
        }
    }

    private func classifyGeometry(_ angle: Double) -> NavigationManeuver {
        let magnitude = abs(angle)
        if magnitude >= 150 { return angle > 0 ? .uTurnRight : .uTurnLeft }
        if magnitude >= 115 { return angle > 0 ? .sharpRight : .sharpLeft }
        if magnitude >= 40 { return angle > 0 ? .right : .left }
        return angle > 0 ? .slightRight : .slightLeft
    }

    private func roundaboutExitNumber(in value: String) -> Int? {
        let patterns = [
            #"(?:loi ra|exit)(?: so| thu| number)?\s*(\d+)"#,
            #"(?:take|use)?\s*(?:the\s*)?(\d+)(?:st|nd|rd|th)\s+exit"#
        ]
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern),
                  let match = expression.firstMatch(
                    in: value,
                    range: NSRange(value.startIndex..., in: value)
                  ),
                  let range = Range(match.range(at: 1), in: value),
                  let number = Int(value[range]),
                  (1...12).contains(number) else { continue }
            return number
        }
        return nil
    }

    private func normalized(_ instruction: String) -> String {
        instruction
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased()
            .replacingOccurrences(of: "đ", with: "d")
    }

    private func contains(_ value: String, any candidates: [String]) -> Bool {
        candidates.contains { value.contains($0) }
    }
}
