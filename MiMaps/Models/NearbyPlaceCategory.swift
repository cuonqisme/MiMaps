import Foundation

enum NearbyPlaceCategory: String, CaseIterable, Identifiable, Sendable {
    case food
    case fuel
    case parking
    case hospital
    case pharmacy
    case atm
    case coffee
    case hotel

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .food: "Ăn uống"
        case .fuel: "Cây xăng"
        case .parking: "Bãi đỗ"
        case .hospital: "Bệnh viện"
        case .pharmacy: "Nhà thuốc"
        case .atm: "ATM"
        case .coffee: "Cà phê"
        case .hotel: "Khách sạn"
        }
    }

    var searchQuery: String {
        switch self {
        case .food: "nhà hàng quán ăn"
        case .fuel: "cây xăng trạm xăng"
        case .parking: "bãi đỗ xe"
        case .hospital: "bệnh viện"
        case .pharmacy: "nhà thuốc"
        case .atm: "ATM ngân hàng"
        case .coffee: "quán cà phê"
        case .hotel: "khách sạn"
        }
    }

    var fallbackSearchQueries: [String] {
        switch self {
        case .food: ["nhà hàng", "restaurant"]
        case .fuel: ["trạm xăng", "gas station"]
        case .parking: ["bãi đỗ xe", "parking"]
        case .hospital: ["bệnh viện", "hospital"]
        case .pharmacy: ["nhà thuốc", "pharmacy"]
        case .atm: ["ATM", "bank"]
        case .coffee: ["quán cà phê", "coffee shop"]
        case .hotel: ["khách sạn", "hotel"]
        }
    }

    var systemImage: String {
        switch self {
        case .food: "fork.knife"
        case .fuel: "fuelpump.fill"
        case .parking: "parkingsign.circle.fill"
        case .hospital: "cross.case.fill"
        case .pharmacy: "pills.fill"
        case .atm: "banknote.fill"
        case .coffee: "cup.and.saucer.fill"
        case .hotel: "bed.double.fill"
        }
    }
}
