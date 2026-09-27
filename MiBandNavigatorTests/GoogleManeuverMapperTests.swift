import XCTest
@testable import MiBandNavigator

final class GoogleManeuverMapperTests: XCTestCase {
    private let mapper = GoogleManeuverMapper()

    func testCoreTurnsAndUTurns() {
        XCTAssertEqual(mapper.map(rawValue: 5), .straight)
        XCTAssertEqual(mapper.map(rawValue: 6), .left)
        XCTAssertEqual(mapper.map(rawValue: 7), .right)
        XCTAssertEqual(mapper.map(rawValue: 10), .slightLeft)
        XCTAssertEqual(mapper.map(rawValue: 13), .sharpRight)
        XCTAssertEqual(mapper.map(rawValue: 14), .uTurnRight)
        XCTAssertEqual(mapper.map(rawValue: 15), .uTurnLeft)
    }

    func testMergeForkAndRampFamilies() {
        XCTAssertEqual(mapper.map(rawValue: 17), .mergeLeft)
        XCTAssertEqual(mapper.map(rawValue: 18), .mergeRight)
        XCTAssertEqual(mapper.map(rawValue: 19), .forkLeft)
        XCTAssertEqual(mapper.map(rawValue: 20), .forkRight)
        XCTAssertEqual(mapper.map(rawValue: 28), .rampLeft)
        XCTAssertEqual(mapper.map(rawValue: 38), .rampRight)
    }

    func testRoundaboutExitDestinationAndUnknown() {
        XCTAssertEqual(mapper.map(rawValue: 43), .roundabout)
        XCTAssertEqual(mapper.map(rawValue: 54, roundaboutTurnNumber: 3), .roundaboutExit(3))
        XCTAssertEqual(mapper.map(rawValue: 2), .destination)
        XCTAssertEqual(mapper.map(rawValue: 999), .unknown)
    }
}
