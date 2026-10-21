import Foundation

/// The newest episode of a show that came out a short time ago. `released` is in milliseconds.
public struct NewEpisode: Hashable, Sendable {
    public var meta: Meta
    public var video: Video
    public var released: Int

    public init(meta: Meta, video: Video, released: Int) {
        self.meta = meta
        self.video = video
        self.released = released
    }
}

/// Finds the episodes of the shows that the viewer follows that came out this week.
public enum NewEpisodes {
    public static let windowMs = 7 * 24 * 60 * 60 * 1000

    /// The most shows that the row asks the addons about.
    public static let maxShows = 20

    /// The shows that the viewer follows: the watchlist and the shows in the history, newest first.
    public static func followed(_ data: LibraryData) -> [MetaPreview] {
        let history = data.progress.values.sorted { $0.updated > $1.updated }.map(\.meta)
        var seen = Set<String>()
        return (data.watchlist + history)
            .filter { $0.type.lowercased() != "movie" }
            .filter { seen.insert($0.id).inserted }
            .prefix(maxShows)
            .map { $0 }
    }

    /// For each show, the newest episode that came out in the last week and that the viewer
    /// did not watch. The newest come first.
    public static func find(_ metas: [Meta], now: Int, watched: Set<String>) -> [NewEpisode] {
        let found = metas.compactMap { meta -> NewEpisode? in
            // Some addons give each episode the same date, often the day of the answer. Those dates say nothing.
            let dates = meta.videos.compactMap { time($0.released) }
            if dates.count > 1 && Set(dates).count == 1 { return nil }
            return meta.videos.compactMap { video -> NewEpisode? in
                guard let released = time(video.released) else { return nil }
                if released > now || released < now - windowMs || watched.contains(video.id) { return nil }
                return NewEpisode(meta: meta, video: video, released: released)
            }
            .max { $0.released < $1.released }
        }
        // Two shows with the same date keep the order of `metas`.
        return found.enumerated()
            .sorted { ($0.element.released, $1.offset) > ($1.element.released, $0.offset) }
            .map(\.element)
    }

    // The formatters are safe to share between threads.
    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// An ISO 8601 time, such as `2026-10-14T10:00:00.000Z`, in milliseconds. Any other text gives nil.
    static func time(_ text: String?) -> Int? {
        guard let text, let date = plain.date(from: text) ?? fractional.date(from: text) else { return nil }
        return Int((date.timeIntervalSince1970 * 1000).rounded())
    }
}
