import Foundation

/// Keeps the source list in the private storage of the app. A configured addon
/// URL can hold a key, so the file is never shared and never goes to a backup.
///
/// `seed` is the list for a first start, when no file exists.
public final class SourceStore: @unchecked Sendable {
    private let file: URL
    private let lock = NSLock()
    private var current: [Source]

    public init(file: URL, seed: String = "") {
        self.file = file
        if let text = try? String(contentsOf: file, encoding: .utf8) {
            current = SourceList.parse(text)
        } else {
            current = SourceList.parse(seed)
        }
    }

    public var sources: [Source] {
        lock.withLock { current }
    }

    /// Replaces the full list. A line that the user removed also removes its source.
    @discardableResult
    public func replace(_ text: String) throws -> [Source] {
        let parsed = SourceList.parse(text)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(SourceList.format(parsed).utf8).write(to: file, options: .atomic)
        lock.withLock { current = parsed }
        return parsed
    }
}
