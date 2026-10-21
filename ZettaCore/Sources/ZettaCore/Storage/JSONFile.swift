import Foundation

/// Keeps one value in memory and in a JSON file. The stores of the library, the
/// settings, and the profiles use it. All calls are safe from any thread.
final class JSONFile<Value: Codable & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var writer: SafeFile
    private var current: Value
    private var observers: [UUID: AsyncStream<Value>.Continuation] = [:]

    /// Reads `file`. A missing or a damaged file gives the value of `fallback`.
    init(file: URL, fallback: () -> Value) {
        writer = SafeFile(file: file)
        current = Self.read(file) ?? fallback()
    }

    var value: Value {
        lock.withLock { current }
    }

    /// Changes the value, tells the observers, and writes the file.
    /// The new value stays in memory also when the write fails, as on Android.
    @discardableResult
    func update<Result>(_ change: (inout Value) -> Result) throws -> Result {
        try lock.withLock {
            var next = current
            let result = change(&next)
            current = next
            for observer in observers.values { observer.yield(next) }
            try writer.write(Self.encode(next))
            return result
        }
    }

    /// Reads another file. Later changes go to that file.
    func switchTo(_ file: URL, fallback: () -> Value) {
        lock.withLock {
            writer = SafeFile(file: file)
            current = Self.read(file) ?? fallback()
            for observer in observers.values { observer.yield(current) }
        }
    }

    /// Gives the value now, and then each new value.
    func updates() -> AsyncStream<Value> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            _ = self.lock.withLock { self.observers.removeValue(forKey: id) }
        }
        lock.withLock {
            continuation.yield(current)
            observers[id] = continuation
        }
        return stream
    }

    static func read(_ file: URL) -> Value? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    static func encode(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
