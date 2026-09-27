import Foundation

struct Destination: Sendable, Equatable, Hashable, Codable, Identifiable {
    let id: UUID
    let placeID: String?
    let displayName: String
    let formattedAddress: String?
    let latitude: Double
    let longitude: Double

    init(
        id: UUID = UUID(),
        placeID: String? = nil,
        displayName: String,
        formattedAddress: String? = nil,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.placeID = placeID
        self.displayName = displayName
        self.formattedAddress = formattedAddress
        self.latitude = latitude
        self.longitude = longitude
    }
}

