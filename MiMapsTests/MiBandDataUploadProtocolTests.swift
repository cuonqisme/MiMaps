import XCTest
@testable import MiMaps

final class MiBandDataUploadProtocolTests: XCTestCase {
    func testIconUploadFollowUpDoesNotRestartForAdditionalFirmwareSizes() {
        XCTAssertEqual(
            MiBandIconUploadFollowUp.resolve(
                pendingManeuver: nil,
                completedManeuver: .left
            ),
            .cacheAdditionalSize
        )
        XCTAssertEqual(
            MiBandIconUploadFollowUp.resolve(
                pendingManeuver: .left,
                completedManeuver: .left
            ),
            .deliverPendingNotification
        )
        XCTAssertEqual(
            MiBandIconUploadFollowUp.resolve(
                pendingManeuver: .right,
                completedManeuver: .left
            ),
            .restartForUpdatedManeuver
        )
    }

    func testBuildsNotificationIconUploadRequest() {
        let bytes = Data([1, 2, 3])
        let command = MiBandDataUploadProtocol.makeUploadRequest(
            type: MiBandDataUploadProtocol.notificationIconType,
            bytes: bytes
        )

        XCTAssertTrue(command.starts(with: [0x08, 0x16, 0x10, 0x00, 0xC2, 0x01]))
        XCTAssertTrue(command.contains(0x32))
        XCTAssertTrue(command.contains(0x10))
        XCTAssertEqual(
            MiBandDataUploadProtocol.md5(bytes).map { String(format: "%02x", $0) }.joined(),
            "5289df737df57326fcdd22597afb1fac"
        )
    }

    func testParsesBandUploadAcknowledgementAndDefaultChunkSize() throws {
        let withChunkSize = Data([
            0x08, 0x16, 0x10, 0x00,
            0xC2, 0x01, 0x09,
            0x12, 0x07,
            0x10, 0x00,
            0x20, 0x00,
            0x28, 0x80, 0x20
        ])
        XCTAssertEqual(
            try MiBandDataUploadProtocol.acknowledgement(from: withChunkSize),
            MiBandDataUploadAcknowledgement(status: 0, resumePosition: 0, chunkSize: 4_096)
        )

        let withoutChunkSize = Data([
            0x08, 0x16, 0x10, 0x00,
            0xC2, 0x01, 0x06,
            0x12, 0x04,
            0x10, 0x00,
            0x20, 0x00
        ])
        XCTAssertEqual(
            try MiBandDataUploadProtocol.acknowledgement(from: withoutChunkSize)?.chunkSize,
            2_048
        )
    }

    func testRejectsNonZeroUploadStatus() {
        let command = Data([
            0x08, 0x16, 0x10, 0x00,
            0xC2, 0x01, 0x04,
            0x12, 0x02,
            0x10, 0x01
        ])
        XCTAssertThrowsError(try MiBandDataUploadProtocol.acknowledgement(from: command)) {
            XCTAssertEqual(
                $0 as? MiBandDataUploadProtocolError,
                .rejected(status: 1, resumePosition: 0)
            )
        }
    }

    func testSplitsUploadStreamWithPartHeaders() throws {
        let parts = try MiBandDataUploadProtocol.uploadParts(
            type: MiBandDataUploadProtocol.notificationIconType,
            bytes: Data([1, 2, 3]),
            chunkSize: 16
        )

        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(Array(parts[0].prefix(4)), [3, 0, 1, 0])
        XCTAssertEqual(Array(parts[1].prefix(4)), [3, 0, 2, 0])
        XCTAssertEqual(Array(parts[2].prefix(4)), [3, 0, 3, 0])
        XCTAssertEqual(MiBandDataUploadProtocol.crc32(Data("123456789".utf8)), 0xCBF4_3926)
    }

    func testBuildsWatchfaceType16UploadWithoutChangingFraming() throws {
        let bytes = Data([0x5A, 0xA5, 0x34, 0x12])
        let request = MiBandDataUploadProtocol.makeUploadRequest(
            type: MiBandWatchfaceProtocol.uploadType,
            bytes: bytes
        )
        let parts = try MiBandDataUploadProtocol.uploadParts(
            type: MiBandWatchfaceProtocol.uploadType,
            bytes: bytes,
            chunkSize: 64
        )

        XCTAssertTrue(request.contains(MiBandWatchfaceProtocol.uploadType))
        XCTAssertEqual(Array(parts[0][4..<6]), [0, MiBandWatchfaceProtocol.uploadType])
        XCTAssertEqual(
            Data(parts[0][6..<22]),
            MiBandDataUploadProtocol.md5(bytes)
        )
    }

    func testParsesMissingBluetoothFrameRequestCapturedFromBand8() {
        let packet = Data([0, 0, 1, 5, 2, 0, 3, 0, 4, 0, 5, 0])

        XCTAssertEqual(
            MiBandDataUploadProtocol.missingChunkIndexes(from: packet),
            [2, 3, 4, 5]
        )
        XCTAssertNil(
            MiBandDataUploadProtocol.missingChunkIndexes(from: Data([0, 0, 1, 1]))
        )
    }
}
