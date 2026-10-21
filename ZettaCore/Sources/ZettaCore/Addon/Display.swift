import Foundation

/// Names and numbers that read correctly for a person.
public enum Display {
    /// Anime addons give the Japanese name in romaji and the English name as an
    /// alias. The first alias in Latin letters is the English name.
    public static func englishName(_ name: String, aliases: [String]) -> String {
        aliases.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty && isLatin($0) } ?? name
    }

    private static func isLatin(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        return letters.filter { $0.value < 0x250 }.count * 10 >= letters.count * 9
    }

    /// Anime Kitsu gives each season as its own title, with the episodes of
    /// season 2 numbered as season 1. The IMDb numbers are correct, so use them.
    public static func video(_ v: Video) -> Video {
        var copy = v
        copy.season = v.imdbSeason ?? v.season
        copy.episode = v.imdbEpisode ?? v.episode
        return copy
    }

    /// The IMDb form of a video ID, such as `tt2560140:1:1` for `kitsu:7442:1`.
    /// Nil for an IMDb ID, or when the title has no IMDb numbers.
    public static func imdbAlias(_ meta: MetaPreview, videoId: String, episodes: [Video]) -> (type: String, id: String)? {
        guard let imdb = meta.imdbId, imdb.hasPrefix("tt"), !videoId.hasPrefix("tt") else { return nil }
        if episodes.isEmpty || meta.type == "movie" { return ("movie", imdb) }
        guard let video = episodes.first(where: { $0.id == videoId }),
              let season = video.imdbSeason, let episode = video.imdbEpisode else { return nil }
        return ("series", "\(imdb):\(season):\(episode)")
    }

    /// The short facts under a card, such as "Movie · 2026". Empty when the addon gives no facts.
    public static func cardFacts(type: String, releaseInfo: String?) -> String {
        [kind(type), year(releaseInfo)].compactMap { $0 }.joined(separator: " · ")
    }

    private static let yearPattern = try! NSRegularExpression(pattern: #"\b(19|20)\d{2}\b"#)

    /// The first year of a release text, such as 2019 for "2019-2023".
    public static func year(_ releaseInfo: String?) -> String? {
        guard let releaseInfo else { return nil }
        let range = NSRange(releaseInfo.startIndex..., in: releaseInfo)
        guard let match = yearPattern.firstMatch(in: releaseInfo, range: range),
              let found = Range(match.range, in: releaseInfo) else { return nil }
        return String(releaseInfo[found])
    }

    /// The rating of a card, such as "7.4". Nil when the addon gives no number above 0.
    public static func rating(_ imdbRating: String?) -> String? {
        guard let text = imdbRating?.trimmingCharacters(in: .whitespacesAndNewlines),
              let value = Double(text), value > 0, value <= 10 else { return nil }
        return String(format: "%.1f", value)
    }

    /// The kind of a title in the singular, such as "Movie".
    public static func kind(_ type: String) -> String? {
        switch type.lowercased() {
        case "movie": return "Movie"
        case "series": return "Series"
        case "anime": return "Anime"
        case "tv", "channel": return "Channel"
        case "": return nil
        default: return type.prefix(1).uppercased() + type.dropFirst()
        }
    }

    private static let metahubPoster = try! NSRegularExpression(pattern: #"^(https://images\.metahub\.space/poster/)(medium|large)(/.*)$"#)

    /// The poster for a card. A card is about 300 pixels wide, so a large picture from
    /// metahub becomes its small size (300 x 450), which is less than half the download.
    public static func cardPoster(_ url: String?) -> String? {
        guard let url else { return nil }
        let range = NSRange(url.startIndex..., in: url)
        return metahubPoster.stringByReplacingMatches(in: url, range: range, withTemplate: "$1small$3")
    }

    /// True for a series whose episode list is one placeholder: a single video with an ID of
    /// four parts, such as `kitsu:7442:1:1`, that some addons give when they do not know the
    /// episodes. A film, and a series with no episodes, are not placeholders.
    public static func isPlaceholder(_ meta: Meta) -> Bool {
        guard meta.type != "movie", meta.videos.count == 1 else { return false }
        return meta.videos[0].id.split(separator: ":", omittingEmptySubsequences: false).count >= 4
    }

    private static let youTubeId = try! NSRegularExpression(pattern: "^[A-Za-z0-9_-]{6,20}$")

    /// The YouTube ID of the trailer. Cinemeta gives `trailerStreams` with `ytId`, and other
    /// addons give `trailers` with `source` and `type`.
    public static func trailer(_ meta: Meta) -> String? {
        func field(_ e: JSONValue, _ name: String) -> String? { e.objectValue == nil ? nil : e[name]?.stringValue }
        let ids = meta.trailerStreams.compactMap { field($0, "ytId") }
            + meta.trailers.filter { (field($0, "type") ?? "Trailer").lowercased() == "trailer" }.compactMap { field($0, "source") }
        return ids.first { youTubeId.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
    }

    /// The names in a list of people. A name can be a text or an object with a name.
    public static func people(_ list: [JSONValue], limit: Int = 6) -> [String] {
        var names: [String] = []
        guard limit > 0 else { return names }
        for e in list {
            let raw: String? = e.objectValue != nil ? e["name"]?.stringValue : e.stringValue
            guard let name = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty, !names.contains(name) else { continue }
            names.append(name)
            if names.count == limit { break }
        }
        return names
    }

    public static func preview(_ m: MetaPreview) -> MetaPreview {
        var copy = m
        copy.name = englishName(m.name, aliases: m.aliases)
        return copy
    }

    public static func meta(_ m: Meta) -> Meta {
        var copy = m
        copy.preview = preview(m.preview)
        copy.videos = m.videos.map(video)
        return copy
    }
}
