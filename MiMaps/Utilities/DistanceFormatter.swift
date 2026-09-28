import Foundation

enum DistanceFormatter {
    static func string(fromMeters meters: Double) -> String {
        let clamped = max(0, meters)
        if clamped < 1_000 {
            return "\(Int(clamped.rounded())) m"
        }

        let kilometers = clamped / 1_000
        if abs(kilometers.rounded() - kilometers) < 0.05 {
            return String(format: "%.0f km", locale: Locale(identifier: "en_US_POSIX"), kilometers)
        }
        return String(format: "%.1f km", locale: Locale(identifier: "en_US_POSIX"), kilometers)
    }
}

