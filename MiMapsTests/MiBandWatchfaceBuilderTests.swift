import XCTest
@testable import MiMaps

final class MiBandWatchfaceBuilderTests: XCTestCase {
    func testBuildsMinimalBand8ContainerWithFullScreenImageAndPreview() throws {
        let pixels = Data(
            repeating: 0,
            count: MiBandWatchfaceBuilder.width * MiBandWatchfaceBuilder.height * 4
        )

        let package = try MiBandWatchfaceBuilder.build(
            identifier: "266299001",
            bgraPixels: pixels
        )
        let bytes = package.bytes

        XCTAssertEqual(package.identifier, "266299001")
        XCTAssertEqual(Array(bytes.prefix(4)), [0x5A, 0xA5, 0x34, 0x12])
        XCTAssertEqual(bytes.uint32(at: 16), 2_048)
        XCTAssertEqual(bytes[28], 1)
        XCTAssertEqual(bytes.uint32(at: 168 + 8), 1)
        XCTAssertEqual(bytes.uint32(at: 168 + 24), 1)

        let imageOffset = Int(bytes.uint32(at: 272 + 8))
        XCTAssertEqual(imageOffset, 304)
        XCTAssertEqual(Array(bytes[imageOffset..<(imageOffset + 4)]), [3, 4, 0, 0])
        XCTAssertEqual(bytes.uint16(at: imageOffset + 4), 192)
        XCTAssertEqual(bytes.uint16(at: imageOffset + 6), 490)
        XCTAssertEqual(
            Array(bytes[(imageOffset + 12)..<(imageOffset + 16)]),
            [0xE0, 0x21, 0xA5, 0x5A]
        )

        let previewOffset = Int(bytes.uint32(at: 32))
        XCTAssertGreaterThan(previewOffset, imageOffset)
        XCTAssertEqual(bytes.uint32(at: 168 + 4), UInt32(previewOffset))
        XCTAssertEqual(
            bytes[imageOffset..<previewOffset],
            bytes[previewOffset..<bytes.count]
        )
    }

    func testEncodesRGB565RunLengthFormatUsedByBand8() throws {
        // Two red pixels followed by one blue pixel, in BGRA byte order.
        let pixels = Data([
            0, 0, 255, 255,
            0, 0, 255, 255,
            255, 0, 0, 255
        ])

        XCTAssertEqual(
            try MiBandWatchfaceBuilder.encodeRGB565RLE(bgraPixels: pixels),
            Data([2, 0x00, 0xF8, 0x81, 0x1F, 0x00])
        )
    }

    func testRejectsInvalidIdentifierDimensionsAndPixelCount() {
        XCTAssertThrowsError(
            try MiBandWatchfaceBuilder.build(
                identifier: "bad-id",
                bgraPixels: Data(repeating: 0, count: 192 * 490 * 4)
            )
        ) {
            XCTAssertEqual($0 as? MiBandWatchfaceBuilderError, .invalidIdentifier)
        }
        XCTAssertThrowsError(
            try MiBandWatchfaceBuilder.build(
                identifier: "266299001",
                bgraPixels: Data(repeating: 0, count: 4),
                width: 1,
                height: 1
            )
        ) {
            XCTAssertEqual($0 as? MiBandWatchfaceBuilderError, .invalidDimensions)
        }
        XCTAssertThrowsError(
            try MiBandWatchfaceBuilder.build(
                identifier: "266299001",
                bgraPixels: Data(repeating: 0, count: 4)
            )
        ) {
            XCTAssertEqual($0 as? MiBandWatchfaceBuilderError, .invalidPixelBuffer)
        }
    }
}

private extension Data {
    func uint16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
