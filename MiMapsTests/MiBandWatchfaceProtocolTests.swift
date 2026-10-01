import XCTest
@testable import MiMaps

final class MiBandWatchfaceProtocolTests: XCTestCase {
    func testValidatesStandardBand8WatchfaceHeaderAndIdentifier() throws {
        var bytes = Data(repeating: 0, count: 0x90)
        bytes[0] = 0x5A
        bytes[1] = 0xA5
        bytes.replaceSubrange(0x28..<(0x28 + 9), with: Data("266240005".utf8))

        let package = try MiBandWatchfacePackage(bytes: bytes)

        XCTAssertEqual(package.identifier, "266240005")
        XCTAssertEqual(package.bytes, bytes)
    }

    func testRejectsNonWatchfacePayloads() {
        XCTAssertThrowsError(try MiBandWatchfacePackage(bytes: Data(repeating: 0, count: 4))) {
            XCTAssertEqual($0 as? MiBandWatchfacePackageError, .tooSmall)
        }

        var wrongMagic = Data(repeating: 0, count: 0x90)
        wrongMagic.replaceSubrange(0x28..<(0x28 + 3), with: Data("123".utf8))
        XCTAssertThrowsError(try MiBandWatchfacePackage(bytes: wrongMagic)) {
            XCTAssertEqual($0 as? MiBandWatchfacePackageError, .invalidMagic)
        }
    }

    func testBuildsInstallStartCommand() {
        let command = MiBandWatchfaceProtocol.makeInstallStartCommand(
            identifier: "266240005",
            byteCount: 658_321
        )

        XCTAssertEqual(
            command.map { String(format: "%02X", $0) }.joined(),
            "080410043211320F0A0932363632343030303510919728"
        )
    }

    func testBuildsSetCommand() {
        let command = MiBandWatchfaceProtocol.makeSetCommand(identifier: "266240005")

        XCTAssertEqual(
            command.map { String(format: "%02X", $0) }.joined(),
            "08041001320B1209323636323430303035"
        )
    }

    func testParsesInstallStatus() throws {
        XCTAssertEqual(
            try MiBandWatchfaceProtocol.installStatus(
                from: Data([0x08, 0x04, 0x10, 0x04, 0x32, 0x02, 0x28, 0x00])
            ),
            0
        )
        XCTAssertNil(
            try MiBandWatchfaceProtocol.installStatus(
                from: Data([0x08, 0x07, 0x10, 0x04])
            )
        )
    }
}
