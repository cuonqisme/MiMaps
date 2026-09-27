import Foundation

@MainActor
protocol BandTransport: AnyObject {
    func start() async throws
    func stop()
    func send(_ instruction: NavigationInstruction) async throws
}

enum BandTransportError: LocalizedError, Equatable {
    case notStarted

    var errorDescription: String? {
        switch self {
        case .notStarted: "Kênh thông báo Mi Band chưa được khởi động."
        }
    }
}

