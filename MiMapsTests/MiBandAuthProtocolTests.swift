import XCTest
@testable import MiMaps

final class MiBandAuthProtocolTests: XCTestCase {
    private let key = "000102030405060708090A0B0C0D0E0F"
    private let phoneNonce = Data((0x10...0x1F).map(UInt8.init))
    private let watchNonce = Data((0x20...0x2F).map(UInt8.init))

    func testBuildsNonceCommandInXiaomiProto2Shape() throws {
        let command = try MiBandAuthProtocol.makePhoneNonceCommand(phoneNonce: phoneNonce)
        XCTAssertEqual(
            command,
            data("0801101A1A15F201120A10101112131415161718191A1B1C1D1E1F")
        )
        XCTAssertEqual(
            MiBandAuthProtocol.plaintextFrame(command).prefix(4),
            Data([0x00, 0x00, 0x02, 0x02])
        )
    }

    func testDerivesKnownSessionVector() throws {
        let session = try MiBandAuthProtocol.deriveSessionKeys(
            secretKey: MiBandAuthProtocol.keyData(from: key),
            phoneNonce: phoneNonce,
            watchNonce: watchNonce
        )

        XCTAssertEqual(session.decryptionKey, data("D738074E6570ABB50D001DB70F497A37"))
        XCTAssertEqual(session.encryptionKey, data("923E295E02AECB7619A8E1B9F574C988"))
        XCTAssertEqual(session.decryptionNonce, data("8676D225"))
        XCTAssertEqual(session.encryptionNonce, data("23869A15"))
    }

    func testParsesAndVerifiesWatchChallenge() throws {
        let command = data(
            "0801101A1A37FA01340A10202122232425262728292A2B2C2D2E2F1220"
                + "17AA8EECAC21D9D71CBA6EA653D126D77ABC2F4D0357F1CCE01D433D40E42235"
        )
        let challenge = try MiBandAuthProtocol.parseWatchChallenge(command: command)
        let session = try MiBandAuthProtocol.deriveSessionKeys(
            secretKey: MiBandAuthProtocol.keyData(from: key),
            phoneNonce: phoneNonce,
            watchNonce: watchNonce
        )
        XCTAssertEqual(challenge.nonce, watchNonce)
        XCTAssertTrue(
            MiBandAuthProtocol.verifyWatch(
                challenge: challenge,
                phoneNonce: phoneNonce,
                sessionKeys: session
            )
        )
    }

    func testParsesWatchChallengeExtractedFromBluetoothFrame() throws {
        let command = data(
            "0801101A1A37FA01340A10202122232425262728292A2B2C2D2E2F1220"
                + "17AA8EECAC21D9D71CBA6EA653D126D77ABC2F4D0357F1CCE01D433D40E42235"
        )
        let frame = MiBandAuthProtocol.plaintextFrame(command)
        let bluetoothBuffer = Data([0xAA, 0xBB]) + frame
        let slicedFrame = bluetoothBuffer.dropFirst(2)

        let payload = try XCTUnwrap(MiBandAuthProtocol.plaintextPayload(from: slicedFrame))
        XCTAssertEqual(payload.startIndex, 0)
        XCTAssertNoThrow(try MiBandAuthProtocol.parseWatchChallenge(command: payload))
    }

    func testRejectsOverflowingVarintInsteadOfTrapping() {
        let malformed = Data(repeating: 0xFF, count: 10) + Data([0x02])
        XCTAssertThrowsError(try MiBandAuthProtocol.parseWatchChallenge(command: malformed)) { error in
            XCTAssertEqual(error as? MiBandAuthProtocolError, .malformedResponse)
        }
    }

    func testRejectsIncorrectWatchProof() throws {
        let session = try MiBandAuthProtocol.deriveSessionKeys(
            secretKey: MiBandAuthProtocol.keyData(from: key),
            phoneNonce: phoneNonce,
            watchNonce: watchNonce
        )
        let challenge = MiBandWatchChallenge(nonce: watchNonce, hmac: Data(repeating: 0, count: 32))
        XCTAssertFalse(
            MiBandAuthProtocol.verifyWatch(
                challenge: challenge,
                phoneNonce: phoneNonce,
                sessionKeys: session
            )
        )
    }

    func testBuildsKnownAESCCMAuthenticationVector() throws {
        let session = try MiBandAuthProtocol.deriveSessionKeys(
            secretKey: MiBandAuthProtocol.keyData(from: key),
            phoneNonce: phoneNonce,
            watchNonce: watchNonce
        )
        let command = try MiBandAuthProtocol.makeAuthenticationCommand(
            phoneNonce: phoneNonce,
            watchNonce: watchNonce,
            sessionKeys: session,
            phoneName: "iPhone MiMaps",
            region: "VN"
        )
        XCTAssertEqual(
            command,
            data(
                "0801101B1A488202450A207E6E4D786282C1AF4441B2ED315DA93C8AE2C820A72DF584D62315D73913A9DC"
                    + "1221806DAD1C238704C048431E48E043C1B6FDD75D8798C3849DCFAA311B78FCBF1914"
            )
        )
    }

    func testRecognizesSuccessfulAuthResponse() throws {
        XCTAssertTrue(try MiBandAuthProtocol.isAuthenticationSuccess(command: data("0801101B1A024001")))
        XCTAssertTrue(try MiBandAuthProtocol.isAuthenticationSuccess(command: data("0801101B1A024000")))
        XCTAssertThrowsError(try MiBandAuthProtocol.isAuthenticationSuccess(command: data("0801101A")))
    }

    private func data(_ hex: String) -> Data {
        var result = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            result.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        return result
    }
}
