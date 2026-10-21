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
