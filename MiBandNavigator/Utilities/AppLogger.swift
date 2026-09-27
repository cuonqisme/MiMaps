import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "MiBandNavigator"

    static let app = Logger(subsystem: subsystem, category: "APP")
    static let navigation = Logger(subsystem: subsystem, category: "NAVIGATION")
    static let google = Logger(subsystem: subsystem, category: "GOOGLE")
    static let notification = Logger(subsystem: subsystem, category: "NOTIFICATION")
    static let band = Logger(subsystem: subsystem, category: "BAND")
    static let permission = Logger(subsystem: subsystem, category: "PERMISSION")
    static let error = Logger(subsystem: subsystem, category: "ERROR")
}
