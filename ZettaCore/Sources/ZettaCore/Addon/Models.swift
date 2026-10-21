import Foundation

/// One title in a catalog. This is the short form of `Meta`.
public struct MetaPreview: Hashable, Sendable, Codable {
    public var id: String
    public var type: String
    public var name: String = ""
    public var poster: String?
    public var posterShape: String?
    public var background: String?
    public var logo: String?
    public var description: String?
    public var releaseInfo: String?
    public var imdbRating: String?
    public var genres: [String] = []
    public var aliases: [String] = []
    /// The IMDb ID of a title from another database, such as Kitsu. Subtitle addons often know only IMDb IDs.
    public var imdbId: String?

    public init(id: String, type: String, name: String = "") {
        self.id = id
        self.type = type
        self.name = name
    }

    public init?(json: JSONValue) {
        guard let id = json["id"]?.stringValue, let type = json["type"]?.stringValue else { return nil }
        self.init(id: id, type: type, name: json["name"]?.stringValue ?? "")
        poster = json["poster"]?.stringValue
        posterShape = json["posterShape"]?.stringValue
        background = json["background"]?.stringValue
        logo = json["logo"]?.stringValue
        description = json["description"]?.stringValue
        releaseInfo = json["releaseInfo"]?.stringValue
        imdbRating = json["imdbRating"]?.stringValue
        genres = json["genres"]?.strings ?? []
        aliases = json["aliases"]?.strings ?? []
        imdbId = json["imdb_id"]?.stringValue
    }
}

/// One episode of a series, or one part of a title.
public struct Video: Hashable, Sendable, Codable {
    public var id: String
    public var title: String?
    public var name: String?
    public var season: Int?
    public var episode: Int?
    public var released: String?
    public var thumbnail: String?
    public var overview: String?
    public var description: String?
    public var imdbSeason: Int?
    public var imdbEpisode: Int?

    public init(id: String, title: String? = nil, season: Int? = nil, episode: Int? = nil, imdbSeason: Int? = nil, imdbEpisode: Int? = nil) {
        self.id = id
        self.title = title
        self.season = season
        self.episode = episode
        self.imdbSeason = imdbSeason
        self.imdbEpisode = imdbEpisode
    }

    public init?(json: JSONValue) {
        guard let id = json["id"]?.stringValue else { return nil }
        self.init(id: id, title: json["title"]?.stringValue, season: json["season"]?.intValue, episode: json["episode"]?.intValue,
                  imdbSeason: json["imdbSeason"]?.intValue, imdbEpisode: json["imdbEpisode"]?.intValue)
        name = json["name"]?.stringValue
        released = json["released"]?.stringValue
        thumbnail = json["thumbnail"]?.stringValue
        overview = json["overview"]?.stringValue
        description = json["description"]?.stringValue
    }

    public var label: String { title ?? name ?? episode.map { "Episode \($0)" } ?? id }
    public var summary: String? { overview ?? description }
}

/// The full details of one title.
public struct Meta: Hashable, Sendable {
    public var preview: MetaPreview
    public var runtime: String?
    public var videos: [Video] = []
    // Addons write these in different forms, so they stay raw JSON.
    public var cast: [JSONValue] = []
    public var director: [JSONValue] = []
    public var trailers: [JSONValue] = []
    public var trailerStreams: [JSONValue] = []

    public init(preview: MetaPreview) {
        self.preview = preview
    }

    public init?(json: JSONValue) {
        guard let preview = MetaPreview(json: json) else { return nil }
        self.init(preview: preview)
        runtime = json["runtime"]?.stringValue
        videos = (json["videos"]?.arrayValue ?? []).compactMap(Video.init(json:))
        cast = json["cast"]?.arrayValue ?? []
        director = json["director"]?.arrayValue ?? []
        trailers = json["trailers"]?.arrayValue ?? []
        trailerStreams = json["trailerStreams"]?.arrayValue ?? []
    }

    public var id: String { preview.id }
    public var type: String { preview.type }
    public var name: String { preview.name }
}

public struct Subtitle: Hashable, Sendable, Codable {
    public var id: String?
    public var url: String
    public var lang: String

    public init(id: String? = nil, url: String, lang: String = "") {
        self.id = id
        self.url = url
        self.lang = lang
    }

    public init?(json: JSONValue) {
        guard let url = json["url"]?.stringValue else { return nil }
        self.init(id: json["id"]?.stringValue, url: url, lang: json["lang"]?.stringValue ?? "")
    }
}

public struct StreamHints: Hashable, Sendable {
    public var notWebReady = false
    public var bingeGroup: String?
    public var filename: String?
    public var requestHeaders: [String: String] = [:]

    public init() {}

    init(json: JSONValue) {
        notWebReady = json["notWebReady"]?.boolValue ?? false
        bingeGroup = json["bingeGroup"]?.stringValue
        filename = json["filename"]?.stringValue
        requestHeaders = (json["proxyHeaders"]?["request"]?.objectValue ?? [:]).compactMapValues(\.stringValue)
    }
}

/// One way to play a video. The name is not `Stream`, because Foundation has a `Stream` class.
public struct AddonStream: Hashable, Sendable {
    public var url: String?
    public var ytId: String?
    public var infoHash: String?
    public var fileIdx: Int?
    public var sources: [String] = []
    public var externalUrl: String?
    public var name: String?
    public var title: String?
    public var description: String?
    public var subtitles: [Subtitle] = []
    public var hints = StreamHints()

    public init(url: String? = nil, infoHash: String? = nil, name: String? = nil, title: String? = nil) {
        self.url = url
        self.infoHash = infoHash
        self.name = name
        self.title = title
    }

    public init(json: JSONValue) {
        self.init(url: json["url"]?.stringValue, infoHash: json["infoHash"]?.stringValue,
                  name: json["name"]?.stringValue, title: json["title"]?.stringValue)
        ytId = json["ytId"]?.stringValue
        fileIdx = json["fileIdx"]?.intValue
        sources = json["sources"]?.strings ?? []
        externalUrl = json["externalUrl"]?.stringValue
        description = json["description"]?.stringValue
        subtitles = (json["subtitles"]?.arrayValue ?? []).compactMap(Subtitle.init(json:))
        if let hints = json["behaviorHints"] { self.hints = StreamHints(json: hints) }
    }

    /// A stream with an HTTP URL.
    public var isHttp: Bool {
        guard let url else { return false }
        return url.hasPrefix("http://") || url.hasPrefix("https://")
    }

    /// A stream with a torrent hash and no HTTP URL. The torrent engine plays it.
    public var isTorrent: Bool {
        !isHttp && infoHash?.count == 40
    }

    /// A YouTube ID or an external link is never playable.
    public func isPlayable(withTorrents: Bool) -> Bool {
        isHttp || (withTorrents && isTorrent)
    }

    /// The headers that the addon tells the player to send.
    public var requestHeaders: [String: String] { hints.requestHeaders }

    /// All text that tells the user what this stream is: the title, the description, and the file name, each one time.
    public var details: String {
        var texts: [String] = []
        for text in [title, description, hints.filename].compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
        where !text.isEmpty && !texts.contains(text) {
            texts.append(text)
        }
        // A text that is a part of a longer one, such as a file name in the title, shows only once.
        return texts.filter { text in !texts.contains { $0 != text && $0.contains(text) } }.joined(separator: "\n")
    }
}
