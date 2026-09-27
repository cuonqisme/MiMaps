import Foundation

enum TravelMode: String, Sendable, Equatable, Hashable, Codable, CaseIterable, Identifiable {
    case motorcycle
    case car
    case walking
    case transit

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .motorcycle: "Xe máy"
        case .car: "Ô tô"
        case .walking: "Đi bộ"
        case .transit: "Công cộng"
        }
    }

    var systemImage: String {
        switch self {
        case .motorcycle: "scooter"
        case .car: "car.fill"
        case .walking: "figure.walk"
        case .transit: "bus.fill"
        }
    }
}
