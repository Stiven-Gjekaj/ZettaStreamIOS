import Foundation

/// The order of the episodes of a title, and the episode that Play starts.
public enum Episodes {
    /// The sort key of a season. Specials (season 0) go last, and an episode with no season goes before them.
    public static func seasonKey(_ season: Int?) -> Int {
        switch season {
        case nil: Int.max - 1
        case 0: Int.max
        case let season?: season
        }
    }

    /// The episodes by season, then by episode number. Equal keys keep the order of the addon.
    public static func sorted(_ videos: [Video]) -> [Video] {
        videos.enumerated()
            .sorted { a, b in
                (seasonKey(a.element.season), a.element.episode ?? 0, a.offset)
                    < (seasonKey(b.element.season), b.element.episode ?? 0, b.offset)
            }
            .map(\.element)
    }

    /// Each season one time, in the order of `seasonKey`.
    public static func seasons(_ videos: [Video]) -> [Int?] {
        var seen: [Int?] = []
        for video in videos where !seen.contains(video.season) { seen.append(video.season) }
        return seen.enumerated()
            .sorted { (seasonKey($0.element), $0.offset) < (seasonKey($1.element), $1.offset) }
            .map(\.element)
    }

    /// The episodes of one season, by episode number.
    public static func of(_ videos: [Video], season: Int?) -> [Video] {
        sorted(videos.filter { $0.season == season })
    }

    /// The name of a season chip.
    public static func seasonName(_ season: Int?) -> String {
        switch season {
        case nil: "Other"
        case 0: "Specials"
        case let season?: "Season \(season)"
        }
    }

    /// The name of an episode for the player and the streams screen, such as "S1 E2  Pilot".
    public static func label(_ video: Video) -> String {
        if let season = video.season, let episode = video.episode { return "S\(season) E\(episode)  \(video.label)" }
        return video.label
    }

    /// The short number of an episode, such as "S1 E2". Nil when the addon gives no season or no episode.
    public static func number(_ video: Video) -> String? {
        guard let season = video.season, let episode = video.episode else { return nil }
        return "S\(season) E\(episode)"
    }

    /// True when the saved position resumes: the video started and did not end.
    public static func resumes(_ progress: WatchProgress?) -> Bool {
        guard let progress else { return false }
        return !progress.isFinished && progress.position > 0
    }

    /// The episode that Play starts: the episode to resume that the viewer watched last,
    /// or else the first episode not watched that is not a special, or else the first episode.
    public static func nextToPlay(_ meta: Meta, _ data: LibraryData) -> Video? {
        let videos = sorted(meta.videos)
        let started = videos.compactMap { v in data.progress[v.id].flatMap { resumes($0) ? (v, $0.updated) : nil } }
        // `max(by:)` keeps the first of equal values, as the Android app does.
        if let resume = started.max(by: { $0.1 < $1.1 })?.0 { return resume }
        return videos.first { !data.watched.contains($0.id) && seasonKey($0.season) != Int.max } ?? videos.first
    }
}
