import XCTest
@testable import MiMaps

final class MiBandWatchfaceProtocolTests: XCTestCase {
    func testValidatesStandardBand8WatchfaceHeaderAndIdentifier() throws {
        let package = try MiBandWatchfaceBuilder.build(
            identifier: "266240005",
            bgraPixels: Data(repeating: 0, count: 192 * 490 * 4)
        )

        XCTAssertEqual(package.identifier, "266240005")
        XCTAssertGreaterThan(package.bytes.count, 0x90)
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

    func testBuildsDeleteCommand() {
        let command = MiBandWatchfaceProtocol.makeDeleteCommand(identifier: "298000001")

        XCTAssertEqual(
            command.map { String(format: "%02X", $0) }.joined(),
            "08041002320B1209323938303030303031"
        )
    }

    func testBuildsListCommandAndParsesActiveRestoreTarget() throws {
        XCTAssertEqual(
            MiBandWatchfaceProtocol.makeListCommand(),
            Data([0x08, 0x04, 0x10, 0x00])
        )
        let info = Data([
            0x0A, 0x03, 0x31, 0x32, 0x33,
            0x12, 0x04, 0x54, 0x65, 0x73, 0x74,
            0x18, 0x01,
            0x20, 0x00
        ])
        var list = Data([0x0A, UInt8(info.count)])
        list.append(info)
        var watchface = Data([0x0A, UInt8(list.count)])
        watchface.append(list)
        var command = Data([0x08, 0x04, 0x10, 0x00, 0x32, UInt8(watchface.count)])
        command.append(watchface)

        XCTAssertEqual(
            try MiBandWatchfaceProtocol.watchfaceList(from: command),
            [
                MiBandWatchfaceProtocol.WatchfaceInfo(
                    identifier: "123",
                    name: "Test",
                    isActive: true,
                    canDelete: false
                )
            ]
        )
    }

    func testParsesSetAcknowledgement() throws {
        XCTAssertEqual(
            try MiBandWatchfaceProtocol.setAcknowledgement(
                from: Data([0x08, 0x04, 0x10, 0x01, 0x32, 0x02, 0x20, 0x01])
            ),
            1
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
