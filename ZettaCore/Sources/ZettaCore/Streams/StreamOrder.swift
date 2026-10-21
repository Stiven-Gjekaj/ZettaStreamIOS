import Foundation

/// A part of the list with a heading.
public struct StreamSection: Hashable, Sendable {
    public var title: String
    public var streams: [ListedStream]

    public init(title: String, streams: [ListedStream]) {
        self.title = title
        self.streams = streams
    }
}

/// Puts the streams in order and chooses the stream to play.
///
/// A group is the list of streams of one addon, in the order of the source list.
/// `ListedStream.list(_:_:)` makes a group from the answer of an addon.
public enum StreamOrder {
    /// Puts the streams in order. Torrents are sorted by seeders. When
    /// `directFirst` is on, all direct links come first, then all torrents.
    /// Otherwise each addon keeps its own part of the list, in the order of
    /// the source list.
    public static func sections(_ groups: [[ListedStream]], directFirst: Bool) -> [StreamSection] {
        if directFirst {
            let all = groups.flatMap { $0 }
            return [
                StreamSection(title: "Direct links", streams: all.filter { !$0.stream.isTorrent }),
                StreamSection(title: "Torrents", streams: bySeeders(all.filter(\.stream.isTorrent))),
            ].filter { !$0.streams.isEmpty }
        }
        return groups.compactMap { items in
            guard let first = items.first else { return nil }
            return StreamSection(title: first.addon.name,
                                 streams: items.filter { !$0.stream.isTorrent } + bySeeders(items.filter(\.stream.isTorrent)))
        }
    }

    /// The resolution that `best` looks for first.
    public static let targetResolution = 1080

    /// A torrent with fewer known seeders than this is a poor choice.
    private static let fewSeeders = 3

    /// What the app remembers of streams that did not start.
    public protocol Health: Sendable {
        func failedRecently(_ listed: ListedStream) -> Bool
        func unreliable(addonUrl: String) -> Bool
    }

    /// No memory: no stream failed and each addon is reliable.
    public struct NoHealth: Health {
        public init() {}
        public func failedRecently(_ listed: ListedStream) -> Bool { false }
        public func unreliable(addonUrl: String) -> Bool { false }
    }

    /// Chooses the stream to play at once. A 1080p stream comes first. With
    /// no 1080p stream, the nearest lower resolution comes next, then a higher
    /// one, then a stream with no known resolution. At the same resolution, the
    /// preferred kind comes first: direct links when `preferDirect` is on,
    /// torrents when it is off. A torrent with almost no seeders comes after
    /// the other streams of its resolution. Then torrents sort by seeders, and
    /// direct links keep the order of the source list.
    public static func best(_ streams: [ListedStream], preferDirect: Bool, maxTorrentBytes: Int64? = nil,
                            health: any Health = NoHealth()) -> ListedStream? {
        ranked(streams, preferDirect: preferDirect, maxTorrentBytes: maxTorrentBytes, health: health).first
    }

    /// The largest torrent that streams well: about 7 Mbit/s for a two hour film
    /// or a 45 minute episode. A larger file needs more speed than most peers give,
    /// and the player stops again and again.
    public static func streamableBytes(type: String) -> Int64 {
        ["movie", "movies", "film"].contains(type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ? 6 * gib : 5 * gib / 2
    }

    private static let gib: Int64 = 1024 * 1024 * 1024

    private static func tooBig(_ listed: ListedStream, _ maxTorrentBytes: Int64?) -> Bool {
        guard let maxTorrentBytes else { return false }
        return listed.stream.isTorrent && (listed.info.sizeBytes ?? 0) > maxTorrentBytes
    }

    private static func almostNoSeeders(_ listed: ListedStream) -> Bool {
        listed.stream.isTorrent && (listed.info.seeders ?? 0) < fewSeeders
    }

    /// All streams, best first, in the order that `best` uses. The player tries the next one when a stream fails.
    /// The streams come in the order of the source list.
    public static func ranked(_ streams: [ListedStream], preferDirect: Bool, maxTorrentBytes: Int64? = nil,
                              health: any Health = NoHealth()) -> [ListedStream] {
        func flag(_ value: Bool) -> Int { value ? 1 : 0 }
        // Each stream gets a list of numbers. A smaller list comes first.
        let keyed = streams.enumerated().map { index, s in
            (s, [
                // A stream that did not start in the last day comes last. An addon with many such streams comes after the others.
                flag(health.failedRecently(s)),
                resolutionRank(s.info.resolution),
                flag(health.unreliable(addonUrl: s.addon.manifestUrl)),
                flag(tooBig(s, maxTorrentBytes)),
                flag(almostNoSeeders(s)),
                flag(s.stream.isTorrent == preferDirect),
                s.stream.isTorrent ? -(s.info.seeders ?? 0) : 0,
                index,
            ])
        }
        return keyed.sorted { $0.1.lexicographicallyPrecedes($1.1) }.map(\.0)
    }

    /// True for a stream that `best` cannot beat: 1080p, of the preferred kind, and not a torrent with almost no seeders.
    public static func isIdeal(_ listed: ListedStream, preferDirect: Bool, maxTorrentBytes: Int64? = nil) -> Bool {
        listed.info.resolution == targetResolution && listed.stream.isTorrent != preferDirect
            && !tooBig(listed, maxTorrentBytes) && !almostNoSeeders(listed)
    }

    private static let labelNoise = StreamRegex(#"[^\p{L}\p{N} .,:+&'()\[\]-]"#)
    private static let labelResolution = StreamRegex(#"(?i)\b(2160|1080|720|480)p\b"#)
    private static let labelSpaces = StreamRegex(#"\s+"#)

    /// A short name for the stream that plays, such as "MultiMoviesProvider · 1080p · 1.4 GB".
    /// The first line of the stream name loses its emoji and its repeated resolution.
    public static func shortLabel(_ listed: ListedStream) -> String {
        let line = (listed.stream.name ?? "").split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r" || $0 == "\r\n" }
            .first.map(String.init) ?? ""
        let part = line.split(omittingEmptySubsequences: false) { $0 == "•" || $0 == "|" }.first.map(String.init) ?? ""
        var name = labelSpaces.replacing(in: labelResolution.replacing(in: labelNoise.replacing(in: part, with: " "), with: " "), with: " ")
        name = String(name.trimmingCharacters(in: .whitespaces).prefix(32))
        if name.isEmpty { name = listed.addon.name }
        return [
            name,
            listed.stream.isTorrent ? "Torrent" : nil,
            listed.info.resolution.map(StreamInfo.resolutionLabel),
            listed.info.sizeBytes.map(StreamInfo.formatSize),
        ].compactMap { $0 }.joined(separator: " · ")
    }

    /// Selects the stream of the next episode from the same source. A stream in
    /// the same binge group comes first, because the addon says that it is the
    /// same source. Then the stream whose data is most like the current one:
    /// resolution, codec, HDR, release group, and audio. A stream with the same
    /// kind (direct or torrent) and the same name breaks a tie, then more seeders,
    /// then the first in the list.
    public static func pickSameSource(_ streams: [AddonStream], bingeGroup: String?, streamName: String?,
                                      current: StreamInfo? = nil, wasTorrent: Bool? = nil) -> AddonStream? {
        let inGroup = streams.filter { bingeGroup != nil && $0.hints.bingeGroup == bingeGroup }
        let pool = inGroup.isEmpty ? streams : inGroup
        func flag(_ value: Bool) -> Int { value ? 1 : 0 }
        // Each stream gets a list of numbers. The largest list wins.
        let keyed = pool.enumerated().map { index, s in
            let info = StreamInfo(s)
            return (s, [
                current.map { StreamInfo.similarity($0, info) } ?? 0,
                flag(wasTorrent != nil && s.isTorrent == wasTorrent),
                flag(streamName != nil && s.name == streamName),
                info.seeders ?? 0,
                -index,
            ])
        }
        return keyed.max { $0.1.lexicographicallyPrecedes($1.1) }?.0
    }

    /// 0 for 1080p. Lower resolutions rank before higher ones. An unknown resolution ranks last.
    private static func resolutionRank(_ resolution: Int?) -> Int {
        guard let resolution else { return Int.max }
        if resolution == targetResolution { return 0 }
        if resolution < targetResolution { return targetResolution - resolution }
        return 100_000 + resolution
    }

    /// Most seeders first. An unknown count comes last. Equal counts keep their order.
    private static func bySeeders(_ items: [ListedStream]) -> [ListedStream] {
        items.enumerated().sorted { a, b in
            let (sa, sb) = (a.element.info.seeders ?? -1, b.element.info.seeders ?? -1)
            return sa != sb ? sa > sb : a.offset < b.offset
        }.map(\.element)
    }
}
