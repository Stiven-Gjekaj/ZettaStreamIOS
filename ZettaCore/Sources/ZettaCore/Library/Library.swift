import Foundation

/// How far the user watched one video. The times are in milliseconds.
/// The name is not `Progress`, because Foundation has a `Progress` class.
public struct WatchProgress: Hashable, Sendable, Codable {
    public var videoId: String
    public var meta: MetaPreview
    public var label: String
    public var position: Int
    public var duration: Int
    public var updated: Int

    public init(videoId: String, meta: MetaPreview, label: String, position: Int, duration: Int, updated: Int) {
        self.videoId = videoId
        self.meta = meta
        self.label = label
        self.position = position
        self.duration = duration
        self.updated = updated
    }

    /// A video counts as watched after 90 percent of it.
    public var isFinished: Bool { duration > 0 && position >= duration * 9 / 10 }
}

/// The library of one profile. The JSON keys are the keys of the Android app.
public struct LibraryData: Hashable, Sendable {
    public var watchlist: [MetaPreview] = []
    public var progress: [String: WatchProgress] = [:]
    public var watched: Set<String> = []
    /// The keys of the live channels that the viewer marked as favourites.
    public var favoriteChannels: Set<String> = []

    public init(watchlist: [MetaPreview] = [], progress: [String: WatchProgress] = [:], watched: Set<String> = [],
                favoriteChannels: Set<String> = []) {
        self.watchlist = watchlist
        self.progress = progress
        self.watched = watched
        self.favoriteChannels = favoriteChannels
    }
}

extension LibraryData: Codable {
    enum CodingKeys: String, CodingKey {
        case watchlist, progress, watched, favoriteChannels
    }

    /// A missing key takes its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        watchlist = try c.decodeIfPresent([MetaPreview].self, forKey: .watchlist) ?? []
        progress = try c.decodeIfPresent([String: WatchProgress].self, forKey: .progress) ?? [:]
        watched = try c.decodeIfPresent(Set<String>.self, forKey: .watched) ?? []
        favoriteChannels = try c.decodeIfPresent(Set<String>.self, forKey: .favoriteChannels) ?? []
    }

    /// A set goes to the file in order, so the same library always gives the same text.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(watchlist, forKey: .watchlist)
        try c.encode(progress, forKey: .progress)
        try c.encode(watched.sorted(), forKey: .watched)
        try c.encode(favoriteChannels.sorted(), forKey: .favoriteChannels)
    }
}

/// Keeps the watchlist and the watch history on the device only.
///
/// `clock` gives the time now in milliseconds. A test gives its own clock.
public final class Library: Sendable {
    private let store: JSONFile<LibraryData>
    private let clock: @Sendable () -> Int

    public init(file: URL, clock: @escaping @Sendable () -> Int = { Int((Date().timeIntervalSince1970 * 1000).rounded()) }) {
        store = JSONFile(file: file) { LibraryData() }
        self.clock = clock
    }

    public var data: LibraryData { store.value }

    /// Gives the library now, and then each changed library.
    public func updates() -> AsyncStream<LibraryData> { store.updates() }

    public func isInWatchlist(_ id: String) -> Bool { data.watchlist.contains { $0.id == id } }

    public func isWatched(_ id: String) -> Bool { data.watched.contains(id) }

    /// Adds the title to the top of the watchlist, or removes it.
    public func toggleWatchlist(_ meta: MetaPreview) throws {
        try store.update { data in
            if data.watchlist.contains(where: { $0.id == meta.id }) {
                data.watchlist.removeAll { $0.id == meta.id }
            } else {
                data.watchlist.insert(meta, at: 0)
            }
        }
    }

    /// Adds the channel to the favourites, or removes it. Gives true when it is a favourite now.
    @discardableResult
    public func toggleFavoriteChannel(_ key: String) throws -> Bool {
        try store.update { data in
            if data.favoriteChannels.remove(key) != nil { return false }
            data.favoriteChannels.insert(key)
            return true
        }
    }

    public func markWatched(_ id: String) throws {
        try store.update { _ = $0.watched.insert(id) }
    }

    public func toggleWatched(_ id: String) throws {
        try store.update { data in
            if data.watched.remove(id) == nil { data.watched.insert(id) }
        }
    }

    /// Keeps the position of a video. A video after 90 percent is also marked as watched.
    public func saveProgress(videoId: String, meta: MetaPreview, label: String, position: Int, duration: Int) throws {
        let entry = WatchProgress(videoId: videoId, meta: meta, label: label, position: position, duration: duration, updated: clock())
        try store.update { data in
            data.progress[videoId] = entry
            if entry.isFinished { data.watched.insert(videoId) }
        }
    }

    public func progress(_ videoId: String) -> WatchProgress? { data.progress[videoId] }

    /// The newest unfinished video of each title, newest first.
    public func continueWatching() -> [WatchProgress] { Self.continueWatching(data) }

    /// Reads the library of another profile from `next`. Later changes go to that file.
    public func switchTo(_ next: URL) {
        store.switchTo(next) { LibraryData() }
    }

    /// Replaces the whole library, for a restore from a backup.
    public func replace(_ data: LibraryData) throws {
        try store.update { $0 = data }
    }

    public func clearHistory() throws {
        try store.update { data in
            data.progress = [:]
            data.watched = []
        }
    }

    public static func continueWatching(_ data: LibraryData) -> [WatchProgress] {
        var seen = Set<String>()
        // Two entries with the same time keep one order: the order of the video IDs.
        return data.progress.values
            .filter { !$0.isFinished && $0.position > 0 }
            .sorted { ($0.updated, $1.videoId) > ($1.updated, $0.videoId) }
            .filter { seen.insert($0.meta.id).inserted }
    }
}
