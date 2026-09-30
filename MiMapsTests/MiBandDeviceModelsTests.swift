import XCTest
@testable import MiMaps

final class MiBandDeviceModelsTests: XCTestCase {
    func testRecognizesMiBand8Names() {
        XCTAssertTrue(MiBandDeviceMatcher.isMiBand8(name: "Xiaomi Smart Band 8"))
        XCTAssertTrue(MiBandDeviceMatcher.isMiBand8(name: "Mi Band 8 A1B2"))
        XCTAssertTrue(MiBandDeviceMatcher.isMiBand8(name: "Smart Band8 Pro"))
    }

    func testRejectsOtherAndMissingDevices() {
        XCTAssertFalse(MiBandDeviceMatcher.isMiBand8(name: nil))
        XCTAssertFalse(MiBandDeviceMatcher.isMiBand8(name: "Xiaomi Smart Band 9"))
        XCTAssertFalse(MiBandDeviceMatcher.isMiBand8(name: "AirPods"))
    }

    func testConnectionStateReadyFlag() {
        XCTAssertTrue(MiBandConnectionState.ready("Band").isReady)
        XCTAssertFalse(MiBandConnectionState.scanning.isReady)
        XCTAssertFalse(MiBandConnectionState.disconnected.isReady)
    }

    func testAuthenticationKeyNormalization() {
        XCTAssertEqual(
            MiBandAuthenticationKey.normalize("0011-2233-4455-6677-8899-aabb-ccdd-eeff"),
            "00112233445566778899AABBCCDDEEFF"
        )
        XCTAssertNil(MiBandAuthenticationKey.normalize("001122"))
        XCTAssertNil(MiBandAuthenticationKey.normalize(String(repeating: "Z", count: 32)))
    }

    func testAuthenticationKeyFingerprintDoesNotExposeFullKey() {
        let key = "00112233445566778899AABBCCDDEEFF"
        let fingerprint = MiBandAuthenticationKey.fingerprint(key)
        XCTAssertEqual(fingerprint, "••••••••EEFF")
        XCTAssertFalse(fingerprint.contains("00112233"))
    }

    func testCapturedPacketPreviewIsBounded() {
        let bytes = Data((0..<70).map(UInt8.init))
        let preview = MiBandCapturedPacket.preview(bytes)
        XCTAssertTrue(preview.hasPrefix("00010203"))
        XCTAssertTrue(preview.hasSuffix("…"))
        XCTAssertEqual(MiBandCapturedPacket.preview(Data([0xAB, 0x01])), "AB01")
    }
}
