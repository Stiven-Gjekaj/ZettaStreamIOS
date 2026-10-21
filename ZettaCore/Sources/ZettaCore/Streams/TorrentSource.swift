import Foundation

/// What the torrent engine needs to play a torrent stream.
public struct TorrentSource: Hashable, Sendable, Codable {
    public var infoHash: String
    /// The index of the file that the addon gave, if any.
    public var fileIdx: Int?
    /// The trackers and DHT nodes of the addon, such as `tracker:udp://...` and `dht:...`.
    public var sources: [String]
    /// The name of the magnet link.
    public var name: String?
    /// The file name that the addon gave. It finds the episode in a season pack.
    public var filename: String?

    public init(infoHash: String, fileIdx: Int? = nil, sources: [String] = [], name: String? = nil, filename: String? = nil) {
        self.infoHash = infoHash
        self.fileIdx = fileIdx
        self.sources = sources
        self.name = name
        self.filename = filename
    }

    /// The magnet link of the torrent, with the trackers of the addon and the public trackers.
    public var magnet: String {
        TorrentMath.magnet(infoHash: infoHash, sources: sources, name: name)
    }

    /// The trackers of the torrent, with no DHT nodes.
    public var trackers: [String] {
        TorrentMath.trackers(sources)
    }
}

extension AddonStream {
    /// The torrent data of a torrent stream. Nil for a direct link.
    /// The name is the file name, or else the first line of the title.
    public var torrentSource: TorrentSource? {
        guard isTorrent, let infoHash else { return nil }
        let firstLine = title.map { String($0.prefix { $0 != "\n" && $0 != "\r" && $0 != "\r\n" }) }
        return TorrentSource(infoHash: infoHash, fileIdx: fileIdx, sources: sources, name: hints.filename ?? firstLine, filename: hints.filename)
    }
}
