import Foundation

/// The streams that did not start, and the times when the streams of each addon did not start.
/// The times are milliseconds since 1970.
public struct HealthData: Hashable, Sendable, Codable {
    public var streams: [String: Int64] = [:]
    public var addons: [String: [Int64]] = [:]

    public init(streams: [String: Int64] = [:], addons: [String: [Int64]] = [:]) {
        self.streams = streams
        self.addons = addons
    }

    // A file from an older version can lack a field.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = try container.decodeIfPresent([String: Int64].self, forKey: .streams) ?? [:]
        addons = try container.decodeIfPresent([String: [Int64]].self, forKey: .addons) ?? [:]
    }
}

/// Remembers the streams that did not start. The app then chooses them last,
/// so that one broken link does not come back each time.
public final class StreamHealth: StreamOrder.Health, @unchecked Sendable {
    public static let streamMemory: Int64 = 24 * 60 * 60_000
    public static let addonFailures = 3

    private let file: URL
    private let clock: @Sendable () -> Int64
    // One lock keeps the data and the file in step, so two writes do not mix.
    private let lock = NSLock()
    private var data: HealthData

    public init(file: URL, clock: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }) {
        self.file = file
        self.clock = clock
        data = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(HealthData.self, from: $0) } ?? HealthData()
    }

    public func failedRecently(_ listed: ListedStream) -> Bool {
        failedRecently(key: Self.key(listed))
    }

    /// True when this stream did not start in the last day.
    public func failedRecently(key: String) -> Bool {
        guard let time = lock.withLock({ data.streams[key] }) else { return false }
        return clock() - time < Self.streamMemory
    }

    /// True when `addonFailures` streams of this addon did not start in the last day, and none started since.
    public func unreliable(addonUrl: String) -> Bool {
        let times = lock.withLock { data.addons[addonUrl] ?? [] }
        let now = clock()
        return times.filter { now - $0 < Self.streamMemory }.count >= Self.addonFailures
    }

    /// Marks a stream that did not start. The mark stays in memory when the file cannot be written.
    public func failed(key: String, addonUrl: String) throws {
        try lock.withLock {
            let now = clock()
            var next = data
            next.streams[key] = now
            next.addons[addonUrl] = Array(((data.addons[addonUrl] ?? []) + [now]).suffix(Self.addonFailures * 2))
            try save(next)
        }
    }

    /// A stream that plays clears its own mark and the marks of its addon.
    public func played(key: String, addonUrl: String) throws {
        try lock.withLock {
            guard data.streams[key] != nil || data.addons[addonUrl] != nil else { return }
            var next = data
            next.streams[key] = nil
            next.addons[addonUrl] = nil
            try save(next)
        }
    }

    /// Call with the lock held.
    private func save(_ next: HealthData) throws {
        let now = clock()
        // Old marks go away, so the file stays small.
        data = HealthData(
            streams: next.streams.filter { now - $0.value < Self.streamMemory },
            addons: next.addons.mapValues { $0.filter { now - $0 < Self.streamMemory } }.filter { !$0.value.isEmpty }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        // The folder of a new profile does not exist before its first write.
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(data).write(to: file, options: .atomic)
    }

    /// One key for each stream: the addon and the link, or the torrent and its file.
    public static func key(addonUrl: String?, url: String?, infoHash: String?, fileIdx: Int?) -> String {
        let link = url.flatMap { $0.isEmpty ? nil : $0 } ?? "\((infoHash ?? "").lowercased()):\(fileIdx ?? -1)"
        return (addonUrl ?? "") + "|" + link
    }

    public static func key(_ listed: ListedStream) -> String {
        key(addonUrl: listed.addon.manifestUrl, url: listed.stream.url, infoHash: listed.stream.infoHash, fileIdx: listed.stream.fileIdx)
    }
}
