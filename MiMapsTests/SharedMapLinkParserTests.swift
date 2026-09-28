import XCTest
@testable import MiMaps

final class SharedMapLinkParserTests: XCTestCase {
    private let parser = SharedMapLinkParser()

    func testParsesGoogleMapsPlaceCoordinateAndName() throws {
        let url = try XCTUnwrap(URL(string: "https://www.google.com/maps/place/FPT+University/@21.0,105.0,15z/data=!4m6!3d20.9905!4d105.5251"))

        XCTAssertEqual(
            parser.parse(url),
            .coordinate(latitude: 20.9905, longitude: 105.5251, name: "FPT University")
        )
    }

    func testParsesGoogleMapsDirectionsDestination() throws {
        let url = try XCTUnwrap(URL(string: "https://www.google.com/maps/dir/?api=1&destination=21.0285%2C105.8542"))

        XCTAssertEqual(
            parser.parse(url),
            .coordinate(latitude: 21.0285, longitude: 105.8542, name: nil)
        )
    }

    func testFallsBackToSharedSearchQuery() throws {
        let url = try XCTUnwrap(URL(string: "https://www.google.com/maps/search/?api=1&query=H%E1%BB%93+Ho%C3%A0n+Ki%E1%BA%BFm"))

        XCTAssertEqual(parser.parse(url), .searchQuery("Hồ Hoàn Kiếm"))
    }
}
