import Foundation

enum DurationFormatter {
    static func string(fromSeconds seconds: TimeInterval) -> String {
        let clamped = max(0, seconds)
        if clamped < 60 { return "<1 phút" }

        let totalMinutes = Int((clamped / 60).rounded())
        if totalMinutes < 60 { return "\(totalMinutes) phút" }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours) giờ" : "\(hours) giờ \(minutes) phút"
    }
}

