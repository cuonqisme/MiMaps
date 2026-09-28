import XCTest
@testable import MiMaps

final class AppleInstructionParserTests: XCTestCase {
    private let parser = AppleInstructionParser()

    func testExtractsVietnameseRoadWithoutRepeatingFullInstruction() {
        XCTAssertEqual(
            parser.conciseRoadName(from: "Rẽ trái vào Quang Trung"),
            "Quang Trung"
        )
        XCTAssertEqual(
            parser.conciseRoadName(from: "Tiếp tục đi về bên phải vào Nguyễn Đức Thuận"),
            "Nguyễn Đức Thuận"
        )
    }

    func testExtractsEnglishRoundaboutRoad() {
        XCTAssertEqual(
            parser.conciseRoadName(from: "At the roundabout take the 2nd exit onto Main Street"),
            "Main Street"
        )
    }

    func testReturnsNilInsteadOfLongActionTextWithoutRoadMarker() {
        XCTAssertNil(parser.conciseRoadName(from: "Continue straight for 8 kilometers"))
    }
}
