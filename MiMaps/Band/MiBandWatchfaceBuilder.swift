import Foundation

enum MiBandWatchfaceBuilderError: LocalizedError, Equatable {
    case invalidIdentifier
    case invalidDimensions
    case invalidPixelBuffer
    case payloadTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier:
            "ID mặt đồng hồ phải gồm từ 1 đến 9 chữ số."
        case .invalidDimensions:
            "Ảnh điều hướng phải có kích thước 192×490 pixel."
        case .invalidPixelBuffer:
            "Bộ đệm ảnh BGRA không đúng kích thước."
        case .payloadTooLarge:
            "Ảnh điều hướng quá lớn để đóng gói cho Mi Band 8."
        }
    }
}

/// Builds the minimal Gen-2 watchface container used by Xiaomi Smart Band 8.
///
/// The package intentionally contains one full-screen image and no actions,
/// applications or AOD face. Pixels use the same RGB565 + RLE v1.0 encoding as
/// Xiaomi's DeviceType 9 compiler. Keeping the encoder in-process makes each
/// navigation update deterministic and avoids bundling an unsigned desktop
/// compiler or any Mi Fitness asset in the iOS application.
enum MiBandWatchfaceBuilder {
    static let width = 192
    static let height = 490

    private static let containerHeader: [UInt8] = [
        0x5A, 0xA5, 0x34, 0x12, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 7, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
        0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0,
        0x31, 0x36, 0x37, 0x32, 0x31, 0x30, 0x30, 0x36, 0x35, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    ]

    private static let faceHeader: [UInt8] = [
        0, 0, 0, 2, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0,
        0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 2, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 3, 0xFF, 0xFF, 0xFF,
        0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0,
        0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 7, 0xFF,
        0xFF, 0xFF, 0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF,
        0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF
    ]

    static func build(
        identifier: String,
        title: String = "MiMaps Navigation",
        bgraPixels: Data,
        width: Int = width,
        height: Int = height
    ) throws -> MiBandWatchfacePackage {
        guard !identifier.isEmpty,
              identifier.count <= 9,
              identifier.utf8.allSatisfy({ (0x30...0x39).contains($0) }) else {
            throw MiBandWatchfaceBuilderError.invalidIdentifier
        }
        guard width == Self.width, height == Self.height else {
            throw MiBandWatchfaceBuilderError.invalidDimensions
        }
        let (expectedBytes, overflow) = width.multipliedReportingOverflow(by: height * 4)
        guard !overflow, bgraPixels.count == expectedBytes else {
            throw MiBandWatchfaceBuilderError.invalidPixelBuffer
        }

        let imageResource = try makeImageResource(
            bgraPixels: bgraPixels,
            width: width,
            height: height
        )
        let imageLogicalLength = imageResource.logicalLength

        let faceOffset = containerHeader.count
        let metadataOffset = faceOffset + faceHeader.count
        let elementTableOffset = metadataOffset
        let imageTableOffset = elementTableOffset + 16
        let elementDataOffset = imageTableOffset + 16
        let imageDataOffset = elementDataOffset + 16

        var output = Data(containerHeader)
        output.append(contentsOf: faceHeader)
        output.append(Data(repeating: 0, count: 48))

        // Header: Gen-2 version, one face, package identity and display title.
        output.setLittleEndian(UInt32(2_048), at: 16)
        output[28] = 1
        output.replaceASCII(identifier, at: MiBandWatchfacePackage.identifierOffset, capacity: 64)
        output.replaceUTF8(title, at: 104, capacity: 64)

        // One element and one image. All unused table counts remain zero.
        output.setLittleEndian(UInt32(1), at: faceOffset + 8)
        output.setLittleEndian(UInt32(elementTableOffset), at: faceOffset + 12)
        output.setLittleEndian(UInt32(imageTableOffset), at: faceOffset + 20)
        output.setLittleEndian(UInt32(1), at: faceOffset + 24)
        output.setLittleEndian(UInt32(imageTableOffset), at: faceOffset + 28)
        for pointerOffset in stride(from: 36, through: 84, by: 8) {
            output.setLittleEndian(UInt32(elementDataOffset), at: faceOffset + pointerOffset)
        }

        // Element metadata points to a 16-byte element payload.
        output[elementTableOffset] = 0
        output.setLittleEndian(UInt32(elementDataOffset), at: elementTableOffset + 8)
        output[elementTableOffset + 12] = 16

        // Image metadata uses object type 2 and points to the compressed block.
        output[imageTableOffset] = 0
        output[imageTableOffset + 3] = 2
        output.setLittleEndian(UInt32(imageDataOffset), at: imageTableOffset + 8)
        output.setLittleEndian(UInt32(imageLogicalLength), at: imageTableOffset + 12)

        // The element payload references image object 0/type 2 at position 0,0.
        output.setLittleEndian(UInt32(0x0200_0000), at: elementDataOffset)
        output.append(imageResource.bytes)

        // Band firmware and companion apps expect a preview; reusing the same
        // image keeps this minimal package self-contained and valid.
        let previewOffset = output.count
        output.setLittleEndian(UInt32(previewOffset), at: 32)
        output.setLittleEndian(UInt32(previewOffset), at: faceOffset + 4)
        output.append(imageResource.bytes)

        return try MiBandWatchfacePackage(bytes: output)
    }

    static func encodeRGB565RLE(bgraPixels: Data) throws -> Data {
        guard bgraPixels.count.isMultiple(of: 4) else {
            throw MiBandWatchfaceBuilderError.invalidPixelBuffer
        }
        let source = [UInt8](bgraPixels)
        var rgb565 = Data(capacity: source.count / 2)
        for offset in stride(from: 0, to: source.count, by: 4) {
            let blue = UInt16(source[offset])
            let green = UInt16(source[offset + 1])
            let red = UInt16(source[offset + 2])
            let value = UInt16(Double(blue) * 31 / 255)
                | (UInt16(Double(green) * 63 / 255) << 5)
                | (UInt16(Double(red) * 31 / 255) << 11)
            rgb565.append(UInt8(truncatingIfNeeded: value))
            rgb565.append(UInt8(truncatingIfNeeded: value >> 8))
        }

        let pixels = [UInt8](rgb565)
        var encoded = Data(capacity: pixels.count)
        var offset = 0
        while offset < pixels.count {
            var runLength = 1
            while runLength < 127,
                  offset + runLength * 2 < pixels.count,
                  pixels[offset] == pixels[offset + runLength * 2],
                  pixels[offset + 1] == pixels[offset + runLength * 2 + 1] {
                runLength += 1
            }
            encoded.append(UInt8(runLength == 1 ? 0x81 : runLength))
            encoded.append(pixels[offset])
            encoded.append(pixels[offset + 1])
            offset += runLength * 2
        }
        return encoded
    }

    private static func makeImageResource(
        bgraPixels: Data,
        width: Int,
        height: Int
    ) throws -> (bytes: Data, logicalLength: Int) {
        let rle = try encodeRGB565RLE(bgraPixels: bgraPixels)
        let rawLength = width * height * 2
        guard rawLength <= Int(UInt32.max) >> 4 else {
            throw MiBandWatchfaceBuilderError.payloadTooLarge
        }

        var compressed = Data([0xE0, 0x21, 0xA5, 0x5A])
        compressed.appendLittleEndian(UInt32(rawLength << 4 | 2))
        compressed.append(rle)

        var resource = Data([3, 4, 0, 0])
        resource.appendLittleEndian(UInt16(width))
        resource.appendLittleEndian(UInt16(height))
        resource.appendLittleEndian(UInt32(compressed.count))
        resource.append(compressed)
        let logicalLength = resource.count
        while !resource.count.isMultiple(of: 4) { resource.append(0) }
        return (resource, logicalLength)
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func setLittleEndian<T: FixedWidthInteger>(_ value: T, at offset: Int) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            replaceSubrange(offset..<(offset + bytes.count), with: bytes)
        }
    }

    mutating func replaceASCII(_ value: String, at offset: Int, capacity: Int) {
        replaceSubrange(
            offset..<(offset + capacity),
            with: Data(repeating: 0, count: capacity)
        )
        replaceSubrange(offset..<(offset + value.utf8.count), with: value.utf8)
    }

    mutating func replaceUTF8(_ value: String, at offset: Int, capacity: Int) {
        replaceSubrange(
            offset..<(offset + capacity),
            with: Data(repeating: 0, count: capacity)
        )
        let bytes = Array(value.utf8.prefix(capacity - 1))
        replaceSubrange(offset..<(offset + bytes.count), with: bytes)
    }
}
