import XCTest
@testable import MiMaps

final class MiBandSystemProtocolTests: XCTestCase {
    func testBuildsAuthoritativeSystemRequests() {
        XCTAssertEqual(MiBandSystemProtocol.makeBatteryCommand(), Data([0x08, 0x02, 0x10, 0x01]))
        XCTAssertEqual(MiBandSystemProtocol.makeDeviceInfoCommand(), Data([0x08, 0x02, 0x10, 0x02]))
        XCTAssertEqual(MiBandSystemProtocol.makeBasicDeviceStateCommand(), Data([0x08, 0x02, 0x10, 0x4E]))
    }

    func testParsesBatteryResponse() throws {
        let command = Data([
            0x08, 0x02, 0x10, 0x01,
            0x22, 0x06,
            0x12, 0x04,
            0x0A, 0x02,
            0x08, 0x41
        ])
        XCTAssertEqual(try MiBandSystemProtocol.batteryLevel(from: command), 65)
    }

    func testParsesBatteryFromBasicDeviceState() throws {
        let command = Data([
            0x08, 0x02, 0x10, 0x4E,
            0x22, 0x05,
            0x82, 0x03, 0x02,
            0x10, 0x41
        ])
        XCTAssertEqual(try MiBandSystemProtocol.batteryLevel(from: command), 65)
    }

    func testParsesFirmwareFromXiaomiDeviceInfo() throws {
        let info = Data([
            0x0A, 0x03, 0x53, 0x4E, 0x31,
            0x12, 0x06, 0x32, 0x2E, 0x33, 0x2E, 0x31, 0x34,
            0x22, 0x07, 0x4D, 0x69, 0x42, 0x61, 0x6E, 0x64, 0x38
        ])
        var system = Data([0x1A, UInt8(info.count)])
        system.append(info)
        var command = Data([0x08, 0x02, 0x10, 0x02, 0x22, UInt8(system.count)])
        command.append(system)

        XCTAssertEqual(
            try MiBandSystemProtocol.deviceInformation(from: command),
            .init(firmware: "2.3.14", model: "MiBand8", serialNumber: "SN1")
        )
    }

    func testRejectsOutOfRangeBattery() {
        let command = Data([
            0x08, 0x02, 0x10, 0x01,
            0x22, 0x06, 0x12, 0x04, 0x0A, 0x02, 0x08, 0x65
        ])
        XCTAssertThrowsError(try MiBandSystemProtocol.batteryLevel(from: command))
    }

    func testRecognizesIncomingChunkFrames() {
        XCTAssertEqual(
            MiBandSessionProtocol.encryptedChunkCount(
                from: Data([0x00, 0x00, 0x00, 0x01, 0x02, 0x00])
            ),
            2
        )
        XCTAssertEqual(
            MiBandSessionProtocol.commandChunk(from: Data([0x02, 0x00, 0xAA, 0xBB])),
            MiBandCommandChunk(index: 2, bytes: Data([0xAA, 0xBB]))
        )
    }
}
