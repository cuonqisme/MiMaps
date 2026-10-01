import UIKit

@MainActor
enum MiBandNavigationCardRenderer {
    static let canvasSize = CGSize(width: 192, height: 490)

    static func render(_ instruction: NavigationInstruction) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            drawManeuver(instruction.maneuver, in: context.cgContext)

            let distance = instruction.maneuver == .destination
                ? "Đã đến nơi"
                : DistanceFormatter.string(fromMeters: instruction.distanceToManeuverMeters)
            drawCentered(
                distance,
                rect: CGRect(x: 10, y: 174, width: 172, height: 44),
                font: .systemFont(ofSize: 31, weight: .bold),
                color: .white
            )

            drawCentered(
                instruction.maneuver.conciseInstruction(roadName: instruction.roadName),
                rect: CGRect(x: 12, y: 224, width: 168, height: 82),
                font: .systemFont(ofSize: 19, weight: .semibold),
                color: .white
            )

            UIColor(white: 0.35, alpha: 1).setFill()
            context.fill(CGRect(x: 20, y: 322, width: 152, height: 1))

            let remainingTime = DurationFormatter.string(
                fromSeconds: instruction.remainingTimeSeconds
            )
            let remainingDistance = DistanceFormatter.string(
                fromMeters: instruction.remainingDistanceMeters
            )
            drawCentered(
                remainingTime,
                rect: CGRect(x: 8, y: 342, width: 176, height: 30),
                font: .systemFont(ofSize: 21, weight: .bold),
                color: .white
            )
            drawCentered(
                remainingDistance,
                rect: CGRect(x: 8, y: 382, width: 176, height: 27),
                font: .systemFont(ofSize: 18, weight: .medium),
                color: UIColor(white: 0.82, alpha: 1)
            )

            if instruction.remainingTimeSeconds > 0 {
                let arrival = instruction.timestamp.addingTimeInterval(
                    instruction.remainingTimeSeconds
                )
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "vi_VN")
                formatter.dateFormat = "HH:mm"
                drawCentered(
                    "Dự kiến \(formatter.string(from: arrival))",
                    rect: CGRect(x: 8, y: 423, width: 176, height: 25),
                    font: .systemFont(ofSize: 16, weight: .regular),
                    color: UIColor(white: 0.7, alpha: 1)
                )
            }
        }
    }

    static func pngData(_ instruction: NavigationInstruction) -> Data? {
        render(instruction).pngData()
    }

    static func watchfacePackage(
        _ instruction: NavigationInstruction,
        identifier: String
    ) throws -> MiBandWatchfacePackage {
        let image = render(instruction)
        guard let cgImage = image.cgImage else {
            throw MiBandWatchfaceBuilderError.invalidPixelBuffer
        }
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        var pixels = Data(repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: width * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                          | CGImageAlphaInfo.premultipliedFirst.rawValue
                  ) else { return false }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else {
            throw MiBandWatchfaceBuilderError.invalidPixelBuffer
        }
        return try MiBandWatchfaceBuilder.build(
            identifier: identifier,
            bgraPixels: pixels
        )
    }

    private static func drawManeuver(
        _ maneuver: NavigationManeuver,
        in context: CGContext
    ) {
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        let image = UIImage(
            systemName: bandSystemImage(for: maneuver),
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 112,
                weight: .bold,
                scale: .large
            )
        )?.withTintColor(.white, renderingMode: .alwaysOriginal)
        image?.draw(
            in: CGRect(x: 30, y: 25, width: 132, height: 132),
            blendMode: .normal,
            alpha: 1
        )

        if case let .roundaboutExit(exit) = maneuver, let exit {
            let badgeRect = CGRect(x: 122, y: 113, width: 45, height: 36)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: badgeRect, cornerRadius: 18).fill()
            drawCentered(
                String(exit),
                rect: badgeRect.insetBy(dx: 2, dy: 1),
                font: .systemFont(ofSize: 22, weight: .black),
                color: .black
            )
        }
    }

    private static func bandSystemImage(for maneuver: NavigationManeuver) -> String {
        switch maneuver {
        case .sharpLeft: "arrow.down.left"
        case .sharpRight: "arrow.down.right"
        default: maneuver.phoneSystemImage
        }
    }

    private static func drawCentered(
        _ value: String,
        rect: CGRect,
        font: UIFont,
        color: UIColor
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.maximumLineHeight = font.lineHeight
        let text = NSString(string: value)
        text.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ],
            context: nil
        )
    }
}
