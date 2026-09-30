import Foundation

enum MiBandNotificationProtocol {
    static let commandType: UInt64 = 7
    static let sendSubtype: UInt64 = 0

    static func makeNotificationCommand(
        id: UInt32,
        title: String,
        body: String,
        date: Date = Date(),
        packageName: String = "com.mimaps",
        appName: String = "MiMaps"
    ) -> Data {
        let notification = fieldString(1, utf8Prefix(packageName, maximumBytes: 24))
            + fieldString(2, utf8Prefix(appName, maximumBytes: 24))
            + fieldString(3, utf8Prefix(title, maximumBytes: 44))
            + fieldString(4, "")
            + fieldString(5, utf8Prefix(body, maximumBytes: 96))
            + fieldString(6, timestamp(date))
            + fieldVarint(7, UInt64(id))
        let level2 = fieldMessage(1, notification)
        let level1 = fieldMessage(3, level2)
        return fieldVarint(1, commandType)
            + fieldVarint(2, sendSubtype)
            + fieldMessage(9, level1)
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return formatter.string(from: date)
    }

    private static func utf8Prefix(_ value: String, maximumBytes: Int) -> String {
        guard maximumBytes > 0 else { return "" }
        var result = ""
        var byteCount = 0
        for character in value {
            let addition = String(character)
            let additionCount = addition.utf8.count
            guard byteCount + additionCount <= maximumBytes else { break }
            result.append(character)
            byteCount += additionCount
        }
        return result
    }

    private static func fieldVarint(_ number: UInt64, _ value: UInt64) -> Data {
        encodeVarint((number << 3) | 0) + encodeVarint(value)
    }

    private static func fieldString(_ number: UInt64, _ value: String) -> Data {
        fieldMessage(number, Data(value.utf8))
    }

    private static func fieldMessage(_ number: UInt64, _ value: Data) -> Data {
        encodeVarint((number << 3) | 2) + encodeVarint(UInt64(value.count)) + value
    }

    private static func encodeVarint(_ value: UInt64) -> Data {
        var remaining = value
        var output = Data()
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            output.append(byte)
        } while remaining != 0
        return output
    }
}
