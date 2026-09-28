import XCTest
@testable import MiMaps

final class AppleManeuverClassifierTests: XCTestCase {
    private let classifier = AppleManeuverClassifier()

    func testVietnameseInstructions() {
        XCTAssertEqual(classifier.classify("Rẽ phải vào Nguyễn Trãi"), .right)
        XCTAssertEqual(classifier.classify("Rẽ gấp trái"), .sharpLeft)
        XCTAssertEqual(classifier.classify("Đi thẳng 2 km"), .straight)
        XCTAssertEqual(classifier.classify("Đi vào vòng xuyến"), .roundabout)
        XCTAssertEqual(classifier.classify("Quay đầu bên phải"), .uTurnRight)
    }

    func testEnglishInstructions() {
        XCTAssertEqual(classifier.classify("Turn left onto Main Street"), .left)
        XCTAssertEqual(classifier.classify("Keep right at the fork"), .slightRight)
        XCTAssertEqual(classifier.classify("Take the ramp left"), .rampLeft)
        XCTAssertEqual(classifier.classify("Continue straight"), .straight)
    }

    func testUnknownInstruction() {
        XCTAssertEqual(classifier.classify("Follow Route 1"), .unknown)
    }
}
