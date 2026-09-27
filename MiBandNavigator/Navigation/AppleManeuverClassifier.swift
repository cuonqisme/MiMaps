import Foundation

struct AppleManeuverClassifier: Sendable {
    func classify(_ instruction: String) -> NavigationManeuver {
        let value = instruction
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased()

        if contains(value, any: ["u-turn", "u turn", "quay dau"]) {
            return contains(value, any: ["right", "phai"]) ? .uTurnRight : .uTurnLeft
        }
        if contains(value, any: ["roundabout", "traffic circle", "vong xuyen", "vong xoay"]) {
            return .roundabout
        }
        if contains(value, any: ["sharp left", "gap trai"]) { return .sharpLeft }
        if contains(value, any: ["sharp right", "gap phai"]) { return .sharpRight }
        if contains(value, any: ["slight left", "keep left", "chech trai", "giu ben trai"]) { return .slightLeft }
        if contains(value, any: ["slight right", "keep right", "chech phai", "giu ben phai"]) { return .slightRight }
        if contains(value, any: ["merge left", "nhap lan trai"]) { return .mergeLeft }
        if contains(value, any: ["merge right", "nhap lan phai"]) { return .mergeRight }
        if contains(value, any: ["ramp left", "loi ra ben trai"]) { return .rampLeft }
        if contains(value, any: ["ramp right", "loi ra ben phai"]) { return .rampRight }
        if contains(value, any: ["turn left", "re trai", "sang trai"]) { return .left }
        if contains(value, any: ["turn right", "re phai", "sang phai"]) { return .right }
        if contains(value, any: ["arrive", "destination", "den noi", "diem den"]) { return .destination }
        if contains(value, any: ["continue", "straight", "head ", "di thang", "tiep tuc"]) { return .straight }
        return .unknown
    }

    private func contains(_ value: String, any candidates: [String]) -> Bool {
        candidates.contains { value.contains($0) }
    }
}
