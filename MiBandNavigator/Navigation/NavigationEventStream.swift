import Foundation

@MainActor
final class NavigationEventStream<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    func stream(initialValue: Value? = nil) -> AsyncStream<Value> {
        let identifier = UUID()
        let pair = AsyncStream.makeStream(of: Value.self, bufferingPolicy: .bufferingNewest(32))
        continuations[identifier] = pair.continuation
        if let initialValue { pair.continuation.yield(initialValue) }
        pair.continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.continuations.removeValue(forKey: identifier)
            }
        }
        return pair.stream
    }

    func yield(_ value: Value) {
        for continuation in continuations.values {
            continuation.yield(value)
        }
    }

    func finish() {
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
    }
}
