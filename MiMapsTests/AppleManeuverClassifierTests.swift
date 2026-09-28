import XCTest
@testable import MiMaps

final class AppleManeuverClassifierTests: XCTestCase {
    private let classifier = AppleManeuverClassifier()

    func testVietnameseInstructions() {
        XCTAssertEqual(classifier.classify("Rẽ phải vào Nguyễn Trãi"), .right)
        XCTAssertEqual(classifier.classify("Rẽ gấp trái"), .sharpLeft)
        XCTAssertEqual(classifier.classify("Đi thẳng 2 km"), .straight)
        XCTAssertEqual(classifier.classify("Đi vào vòng xuyến"), .roundabout)
        XCTAssertEqual(classifier.classify("Vào vòng xuyến, đi theo lối ra thứ 3"), .roundaboutExit(3))
        XCTAssertEqual(classifier.classify("Quay đầu bên phải"), .uTurnRight)
        XCTAssertEqual(classifier.classify("Tiếp tục đi về bên trái"), .slightLeft)
        XCTAssertEqual(classifier.classify("Tiếp tục đi về bên phải"), .slightRight)
    }

    func testEnglishInstructions() {
        XCTAssertEqual(classifier.classify("Turn left onto Main Street"), .left)
        XCTAssertEqual(classifier.classify("Keep right at the fork"), .slightRight)
        XCTAssertEqual(classifier.classify("Take the ramp left"), .rampLeft)
        XCTAssertEqual(classifier.classify("Continue straight"), .straight)
        XCTAssertEqual(classifier.classify("At the roundabout take the 2nd exit"), .roundaboutExit(2))
    }

    func testGeometryCorrectsContradictoryTextDirection() {
        XCTAssertEqual(classifier.classify("Rẽ trái", turnAngleDegrees: 70), .right)
        XCTAssertEqual(classifier.classify("Rẽ phải", turnAngleDegrees: -65), .left)
        XCTAssertEqual(classifier.classify("Tiếp tục", turnAngleDegrees: 25), .slightRight)
    }

    func testUnknownInstruction() {
        XCTAssertEqual(classifier.classify("Follow Route 1"), .unknown)
    }
}
