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
}

