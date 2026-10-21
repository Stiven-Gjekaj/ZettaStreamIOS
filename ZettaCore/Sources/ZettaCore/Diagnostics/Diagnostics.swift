import Foundation

/// Keeps the last events of the player, the torrent engine, and the addons in
/// memory. A page shows them, so that a fault can be found without a cable.
/// Nothing goes to a server, and nothing goes to a file.
public final class Diagnostics: @unchecked Sendable {
    /// The one store of the app.
    public static let shared = Diagnostics()

    public static let maxLines = 500

    public let maxLines: Int
    // The lock keeps the lines and the formatter safe when many tasks write at the same time.
    private let lock = NSLock()
    private var lines: [String] = []
    private var first = 0
    private let time: DateFormatter
    private let now: @Sendable () -> Date
    private var echo = false

    public init(maxLines: Int = Diagnostics.maxLines, now: @escaping @Sendable () -> Date = Date.init) {
        self.maxLines = max(maxLines, 1)
        self.now = now
        time = DateFormatter()
        time.locale = Locale(identifier: "en_US_POSIX")
        time.dateFormat = "HH:mm:ss"
    }

    /// Only a debug build also writes to the console. A release build keeps the
    /// lines in memory only, because they hold the links of the streams.
    public var toConsole: Bool {
        get { lock.withLock { echo } }
        set { lock.withLock { echo = newValue } }
    }

    /// Adds one line, such as "14:02:11 Player: error at 1000 (HTTPError: HTTP 503 from ...)".
    public func log(_ tag: String, _ message: String, error: Error? = nil) {
        let reason = error.map { " (\(type(of: $0)): \($0))" } ?? ""
        let console: Bool = lock.withLock {
            let line = "\(time.string(from: now())) \(tag): \(message)\(reason)"
            // The lines are a ring: a full store writes over its oldest line.
            if lines.count < maxLines {
                lines.append(line)
            } else {
                lines[first] = line
                first = (first + 1) % maxLines
            }
            return echo
        }
        if console { NSLog("Z%@: %@", tag, message + reason) }
    }

    /// The lines, the oldest first.
    public func allLines() -> [String] {
        lock.withLock { Array(lines[first...] + lines[..<first]) }
    }

    public func clear() {
        lock.withLock {
            lines.removeAll()
            first = 0
        }
    }
}
