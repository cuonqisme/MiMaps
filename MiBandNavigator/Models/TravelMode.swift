import Foundation

enum TravelMode: String, Sendable, Equatable, Hashable, Codable, CaseIterable, Identifiable {
    case motorcycle
    case car

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .motorcycle: "Xe máy"
        case .car: "Ô tô"
        }
    }
}

