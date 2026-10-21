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

    /// Most seeders first. An unknown count comes last. Equal counts keep their order.
    private static func bySeeders(_ items: [ListedStream]) -> [ListedStream] {
        items.enumerated().sorted { a, b in
            let (sa, sb) = (a.element.info.seeders ?? -1, b.element.info.seeders ?? -1)
            return sa != sb ? sa > sb : a.offset < b.offset
        }.map(\.element)
    }
}
