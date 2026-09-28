import Foundation

struct AppleInstructionParser: Sendable {
    func conciseRoadName(from instruction: String) -> String? {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased()
            .replacingOccurrences(of: "đ", with: "d")
        let markers = [" vao ", " onto ", " toward ", " towards "]

        var bestEnd: String.Index?
        for marker in markers {
            guard let range = normalized.range(of: marker, options: .backwards) else { continue }
            if bestEnd == nil || range.upperBound > bestEnd! { bestEnd = range.upperBound }
        }

        guard let bestEnd else { return nil }
        let offset = normalized.distance(from: normalized.startIndex, to: bestEnd)
        guard let originalStart = trimmed.index(trimmed.startIndex, offsetBy: offset, limitedBy: trimmed.endIndex) else {
            return nil
        }

        var road = String(trimmed[originalStart...])
        for separator in [" rồi ", " then ", ";", " • "] {
            if let range = road.range(of: separator, options: [.caseInsensitive, .diacriticInsensitive]) {
                road = String(road[..<range.lowerBound])
            }
        }
        road = road.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !road.isEmpty else { return nil }
        return String(road.prefix(48))
    }
}
