import Foundation

struct Destination: Sendable, Equatable, Hashable, Codable, Identifiable {
    let id: UUID
    let placeID: String?
    let displayName: String
    let formattedAddress: String?
    let phoneNumber: String?
    let websiteURL: URL?
    let latitude: Double
    let longitude: Double

    init(
        id: UUID = UUID(),
        placeID: String? = nil,
        displayName: String,
        formattedAddress: String? = nil,
        phoneNumber: String? = nil,
        websiteURL: URL? = nil,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.placeID = placeID
        self.displayName = displayName
        self.formattedAddress = formattedAddress
        self.phoneNumber = phoneNumber
        self.websiteURL = websiteURL
        self.latitude = latitude
        self.longitude = longitude
    }
}
