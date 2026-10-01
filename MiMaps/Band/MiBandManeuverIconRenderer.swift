import UIKit

enum MiBandManeuverIconRendererError: LocalizedError, Equatable {
    case invalidSize
    case unsupportedPixelFormat(Int)
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .invalidSize:
            "Kích thước icon Mi Band không hợp lệ."
        case let .unsupportedPixelFormat(format):
            "Mi Band yêu cầu định dạng pixel chưa hỗ trợ: \(format)."
        case .renderingFailed:
            "Không thể vẽ icon điều hướng cho Mi Band."
        }
    }
}

@MainActor
enum MiBandManeuverIconRenderer {
    static func packageName(for maneuver: NavigationManeuver?) -> String {
        guard let maneuver else { return "com.mimaps" }
        // The Band caches notification icons by package name. Keep the alias
        // short enough for Xiaomi's package field and revision it whenever the
        // on-wire icon format changes, so a stale/partial com.mimaps upload
        // cannot suppress the package-query handshake forever.
        return "com.mimaps.p4.\(cacheToken(for: maneuver))"
    }

    static func maneuver(forPackageName packageName: String) -> NavigationManeuver? {
        guard let token = packageName.split(separator: ".").last.map(String.init) else {
            return nil
        }
        if packageName.hasPrefix("com.mimaps.p4.")
            || packageName.hasPrefix("com.mimaps.p3.") {
            return maneuver(forCacheToken: token)
        }
        guard packageName.hasPrefix("com.mimaps.nav.") else { return nil }
        return maneuver(for: token)
    }

    private static func cacheToken(for maneuver: NavigationManeuver) -> String {
        switch maneuver {
        case .straight: "s"
        case .slightLeft: "sl"
        case .left: "l"
        case .sharpLeft: "hl"
        case .slightRight: "sr"
        case .right: "r"
        case .sharpRight: "hr"
        case .uTurnLeft: "ul"
        case .uTurnRight: "ur"
        case .mergeLeft, .forkLeft, .rampLeft: "ml"
        case .mergeRight, .forkRight, .rampRight: "mr"
        case .roundabout, .roundaboutExit: "rb"
        case .destination: "d"
        case .unknown: "n"
        }
    }

    private static func maneuver(forCacheToken token: String) -> NavigationManeuver? {
        switch token {
        case "s": .straight
        case "sl": .slightLeft
        case "l": .left
        case "hl": .sharpLeft
        case "sr": .slightRight
        case "r": .right
        case "hr": .sharpRight
        case "ul": .uTurnLeft
        case "ur": .uTurnRight
        case "ml": .mergeLeft
        case "mr": .mergeRight
        case "rb": .roundabout
        case "d": .destination
        case "n": .unknown
        default: nil
        }
    }

    static func pixelData(
        maneuver: NavigationManeuver?,
        size: Int,
        pixelFormat: Int
    ) throws -> Data {
        guard (8...256).contains(size) else {
            throw MiBandManeuverIconRendererError.invalidSize
        }

        let bytesPerRow = size * 4
        var bgra = [UInt8](repeating: 0, count: bytesPerRow * size)
        try bgra.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                    | CGImageAlphaInfo.premultipliedFirst.rawValue
            ) else {
                throw MiBandManeuverIconRendererError.renderingFailed
            }

            context.clear(CGRect(x: 0, y: 0, width: size, height: size))
            UIGraphicsPushContext(context)
            defer { UIGraphicsPopContext() }

            let symbol = UIImage(
                systemName: systemImage(for: maneuver),
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: CGFloat(size) * 0.78,
                    weight: .black,
                    scale: .large
                )
            )?.withTintColor(.white, renderingMode: .alwaysOriginal)
            guard let symbol else {
                throw MiBandManeuverIconRendererError.renderingFailed
            }
            let inset = max(1, CGFloat(size) * 0.07)
            symbol.draw(in: CGRect(
                x: inset,
                y: inset,
                width: CGFloat(size) - inset * 2,
                height: CGFloat(size) - inset * 2
            ))
        }

        switch pixelFormat {
        case 0:
            return rgb565(bgra, littleEndian: true)
        case 1:
            return rgb565(bgra, littleEndian: false)
        case 2:
            var xrgb = bgra
            for alphaOffset in stride(from: 3, to: xrgb.count, by: 4) {
                xrgb[alphaOffset] = 0xFF
            }
            return Data(xrgb)
        case 3:
            return Data(bgra)
        case 7:
            return argb8565(bgra, swapRedBlue: false)
        case 8:
            return argb8565(bgra, swapRedBlue: true)
        default:
            throw MiBandManeuverIconRendererError.unsupportedPixelFormat(pixelFormat)
        }
    }

    private static func token(for maneuver: NavigationManeuver?) -> String {
        switch maneuver {
        case .straight: "straight"
        case .slightLeft: "slightleft"
        case .left: "left"
        case .sharpLeft: "sharpleft"
        case .slightRight: "slightright"
        case .right: "right"
        case .sharpRight: "sharpright"
        case .uTurnLeft: "uturnleft"
        case .uTurnRight: "uturnright"
        case .mergeLeft, .forkLeft, .rampLeft: "mergeleft"
        case .mergeRight, .forkRight, .rampRight: "mergeright"
        case .roundabout, .roundaboutExit: "roundabout"
        case .destination: "destination"
        case .unknown, nil: "navigation"
        }
    }

    private static func maneuver(for token: String) -> NavigationManeuver? {
        switch token {
        case "straight": .straight
        case "slightleft": .slightLeft
        case "left": .left
        case "sharpleft": .sharpLeft
        case "slightright": .slightRight
        case "right": .right
        case "sharpright": .sharpRight
        case "uturnleft": .uTurnLeft
        case "uturnright": .uTurnRight
        case "mergeleft": .mergeLeft
        case "mergeright": .mergeRight
        case "roundabout": .roundabout
        case "destination": .destination
        default: nil
        }
    }

    private static func rgb565(_ bgra: [UInt8], littleEndian: Bool) -> Data {
        var output = Data(capacity: bgra.count / 2)
        for offset in stride(from: 0, to: bgra.count, by: 4) {
            let blue = UInt16(bgra[offset]) >> 3
            let green = UInt16(bgra[offset + 1]) >> 2
            let red = UInt16(bgra[offset + 2]) >> 3
            let value = (red << 11) | (green << 5) | blue
            if littleEndian {
                output.append(UInt8(value & 0xFF))
                output.append(UInt8(value >> 8))
            } else {
                output.append(UInt8(value >> 8))
                output.append(UInt8(value & 0xFF))
            }
        }
        return output
    }

    private static func argb8565(_ bgra: [UInt8], swapRedBlue: Bool) -> Data {
        var output = Data(capacity: bgra.count / 4 * 3)
        for offset in stride(from: 0, to: bgra.count, by: 4) {
            let originalBlue = UInt16(bgra[offset]) >> 3
            let green = UInt16(bgra[offset + 1]) >> 2
            let originalRed = UInt16(bgra[offset + 2]) >> 3
            let red = swapRedBlue ? originalBlue : originalRed
            let blue = swapRedBlue ? originalRed : originalBlue
            let value = (red << 11) | (green << 5) | blue
            output.append(UInt8(value & 0xFF))
            output.append(UInt8(value >> 8))
            output.append(bgra[offset + 3])
        }
        return output
    }

    private static func systemImage(for maneuver: NavigationManeuver?) -> String {
        switch maneuver {
        case .sharpLeft: "arrow.down.left"
        case .sharpRight: "arrow.down.right"
        case .destination: "mappin.and.ellipse"
        case .unknown, nil: "location.north.fill"
        default: maneuver?.phoneSystemImage ?? "location.north.fill"
        }
    }
}
