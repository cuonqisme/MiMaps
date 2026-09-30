import XCTest
@testable import MiMaps

final class MiBandNotificationIconProtocolTests: XCTestCase {
    func testParsesPackageQueryAndBuildsReply() throws {
        let package = Data("com.mimaps".utf8)
        let packageMessage = Data([0x0A, UInt8(package.count)]) + package
        let notification = Data([0x82, 0x01, UInt8(packageMessage.count)]) + packageMessage
        let command = Data([0x08, 0x07, 0x10, 0x10, 0x4A, UInt8(notification.count)])
            + notification

        XCTAssertEqual(
            try MiBandNotificationIconProtocol.packageQuery(from: command),
            "com.mimaps"
        )
        XCTAssertEqual(
            MiBandNotificationIconProtocol.makePackageReply(package: "com.mimaps"),
            Data([0x08, 0x07, 0x10, 0x0F, 0x4A, 0x0E, 0x72, 0x0C, 0x0A, 0x0A])
                + Data("com.mimaps".utf8)
        )
    }

    func testParsesIconRequest() throws {
        let request = Data([0x08, 0x00, 0x10, 0x03, 0x18, 0x40])
        let notification = Data([0x7A, UInt8(request.count)]) + request
        let command = Data([0x08, 0x07, 0x10, 0x0F, 0x4A, UInt8(notification.count)])
            + notification

        XCTAssertEqual(
            try MiBandNotificationIconProtocol.iconRequest(from: command),
            MiBandNotificationIconRequest(status: 0, pixelFormat: 3, size: 64)
        )
    }

    func testIgnoresUnrelatedCommands() throws {
        XCTAssertNil(
            try MiBandNotificationIconProtocol.packageQuery(
                from: Data([0x08, 0x02, 0x10, 0x01])
            )
        )
    }
}
