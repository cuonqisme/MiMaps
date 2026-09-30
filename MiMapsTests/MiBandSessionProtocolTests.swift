import XCTest
@testable import MiMaps

final class MiBandSessionProtocolTests: XCTestCase {
    func testEncryptsAndDecryptsSinglePacketWithCounter() throws {
        let key = Data((0x00...0x0F).map(UInt8.init))
        let nonce = Data([0x10, 0x11, 0x12, 0x13])
        let keys = MiBandSessionKeys(
            decryptionKey: key,
            encryptionKey: key,
            decryptionNonce: nonce,
            encryptionNonce: nonce
        )
        let command = Data([0x08, 0x07, 0x10, 0x00, 0x4A, 0x00])

        let outgoing = try MiBandSessionProtocol.makeEncryptedSingleFrame(
            command: command,
            sessionKeys: keys,
            counter: 1
        )

        XCTAssertEqual(outgoing.prefix(6), Data([0x00, 0x00, 0x02, 0x01, 0x01, 0x00]))
        let simulatedIncoming = Data(outgoing.prefix(4)) + Data(outgoing.dropFirst(6))
        XCTAssertEqual(
            try MiBandSessionProtocol.decryptIncomingSingleFrame(
                simulatedIncoming,
                sessionKeys: keys
            ),
            command
        )
    }

    func testRecognizesAcknowledgementAndEnvelope() {
        XCTAssertEqual(
            MiBandSessionProtocol.acknowledgementResult(
                from: Data([0x00, 0x00, 0x03, 0x00])
            ),
            0
        )
        XCTAssertEqual(
            MiBandSessionProtocol.commandEnvelope(
                from: Data([0x08, 0x07, 0x10, 0x00, 0x4A, 0x00])
            ),
            MiBandCommandEnvelope(type: 7, subtype: 0)
        )
    }

    func testBuildsCompactNotificationCommand() {
        let command = MiBandNotificationProtocol.makeNotificationCommand(
            id: 42,
            title: "← 100 m",
            body: "Rẽ trái · MiMaps",
            date: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(command.prefix(4), Data([0x08, 0x07, 0x10, 0x00]))
        XCTAssertNotNil(command.range(of: Data("com.mimaps".utf8)))
        XCTAssertNotNil(command.range(of: Data("← 100 m".utf8)))
        XCTAssertNotNil(command.range(of: Data("Rẽ trái · MiMaps".utf8)))
        XCTAssertLessThan(command.count, 200)
    }

    func testNotificationTruncationPreservesValidUTF8() {
        let command = MiBandNotificationProtocol.makeNotificationCommand(
            id: 1,
            title: String(repeating: "➡️", count: 100),
            body: String(repeating: "đường ", count: 100)
        )

        XCTAssertLessThan(command.count, 220)
        XCTAssertNotNil(command.range(of: Data("➡️".utf8)))
        XCTAssertNotNil(command.range(of: Data("đường".utf8)))
    }
}
