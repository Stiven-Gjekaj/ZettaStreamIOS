import Foundation
import Testing
@testable import ZettaCore

struct DisplayTests {
    @Test func theFirstLatinAliasIsTheEnglishName() {
        #expect(Display.englishName("Boku no Hero Academia 2", aliases: ["My Hero Academia Season 2", "Boku no Hero Academia 2"]) == "My Hero Academia Season 2")
        #expect(Display.englishName("Mushoku Tensei", aliases: ["無職転生", "Mushoku Tensei: Jobless Reincarnation"]) == "Mushoku Tensei: Jobless Reincarnation")
    }

    @Test func withNoLatinAliasTheNameStays() {
        #expect(Display.englishName("Frieren", aliases: []) == "Frieren")
        #expect(Display.englishName("Frieren", aliases: ["葬送のフリーレン"]) == "Frieren")
    }

    @Test func theImdbNumbersReplaceTheKitsuNumbers() {
        let v = Display.video(Video(id: "kitsu:12268:1", season: 1, episode: 1, imdbSeason: 2, imdbEpisode: 1))
        #expect(v.season == 2)
        #expect(v.episode == 1)
        #expect(v.id == "kitsu:12268:1")
    }

    @Test func withNoImdbNumbersTheVideoStays() {
        let v = Video(id: "tt1:1:3", season: 1, episode: 3)
        #expect(Display.video(v) == v)
    }

    @Test func anAnimeEpisodeHasAnImdbFormForSubtitles() {
        var meta = MetaPreview(id: "kitsu:7442", type: "anime")
        meta.imdbId = "tt2560140"
        let episodes = [Video(id: "kitsu:7442:1", season: 1, episode: 1, imdbSeason: 1, imdbEpisode: 1)]
        let series = Display.imdbAlias(meta, videoId: "kitsu:7442:1", episodes: episodes)
        #expect(series?.type == "series" && series?.id == "tt2560140:1:1")
        var film = meta
        film.type = "movie"
        let movie = Display.imdbAlias(film, videoId: "kitsu:7442", episodes: [])
        #expect(movie?.type == "movie" && movie?.id == "tt2560140")
        var imdb = meta
        imdb.id = "tt2560140"
        #expect(Display.imdbAlias(imdb, videoId: "tt2560140:1:1", episodes: episodes) == nil)
        var none = meta
        none.imdbId = nil
        #expect(Display.imdbAlias(none, videoId: "kitsu:7442:1", episodes: episodes) == nil)
    }

    @Test func aCardShowsTheKindAndTheFirstYear() {
        #expect(Display.cardFacts(type: "movie", releaseInfo: "2026") == "Movie · 2026")
        #expect(Display.cardFacts(type: "series", releaseInfo: "2019–2023") == "Series · 2019")
        #expect(Display.cardFacts(type: "anime", releaseInfo: "Oct 2024") == "Anime · 2024")
        #expect(Display.cardFacts(type: "tv", releaseInfo: nil) == "Channel")
        #expect(Display.cardFacts(type: "series", releaseInfo: "soon") == "Series")
    }

    @Test func aRatingHasOneDecimalAndOnlyAValidNumberShows() {
        #expect(Display.rating("7.4") == "7.4")
        #expect(Display.rating(" 8 ") == "8.0")
        #expect(Display.rating("0") == nil)
        #expect(Display.rating("N/A") == nil)
        #expect(Display.rating("74") == nil)
        #expect(Display.rating(nil) == nil)
    }

    @Test func aCardAsksForTheSmallMetahubPoster() {
        #expect(Display.cardPoster("https://images.metahub.space/poster/medium/tt1/img") == "https://images.metahub.space/poster/small/tt1/img")
        #expect(Display.cardPoster("https://images.metahub.space/poster/large/tt1/img") == "https://images.metahub.space/poster/small/tt1/img")
        #expect(Display.cardPoster("https://images.metahub.space/poster/small/tt1/img") == "https://images.metahub.space/poster/small/tt1/img")
        #expect(Display.cardPoster("https://media.kitsu.app/anime/1/poster.jpg") == "https://media.kitsu.app/anime/1/poster.jpg")
        #expect(Display.cardPoster(nil) == nil)
    }

    private func meta(_ id: String, _ type: String, videos: [String] = []) -> Meta {
        var meta = Meta(preview: MetaPreview(id: id, type: type))
        meta.videos = videos.map { Video(id: $0) }
        return meta
    }

    @Test func aSeriesWithOnePlaceholderEpisodeIsAPlaceholder() {
        #expect(Display.isPlaceholder(meta("kitsu:7442", "series", videos: ["kitsu:7442:1:1"])))
        #expect(!Display.isPlaceholder(meta("kitsu:7442", "series", videos: ["kitsu:7442:1", "kitsu:7442:2"])))
        #expect(!Display.isPlaceholder(meta("tt1", "series", videos: ["tt1:1:1"])))
        #expect(!Display.isPlaceholder(meta("tt2", "movie", videos: ["tt2:a:b:c"])))
    }

    private func list(_ text: String) throws -> [JSONValue] {
        try #require(try JSONValue.parse(Data(text.utf8)).arrayValue)
    }

    @Test func theTrailerComesFromEitherForm() throws {
        var cinemeta = meta("tt1", "movie")
        cinemeta.trailerStreams = try list(#"[{"title":"A","ytId":"PLl99DlL6b4"}]"#)
        #expect(Display.trailer(cinemeta) == "PLl99DlL6b4")
        var other = meta("k", "series")
        other.trailers = try list(#"[{"source":"LHtdKWJdif4","type":"Trailer"}]"#)
        #expect(Display.trailer(other) == "LHtdKWJdif4")
        other.trailers = try list(#"[{"source":"x y","type":"Trailer"}]"#)
        #expect(Display.trailer(other) == nil)
        other.trailers = try list(#"[{"source":"LHtdKWJdif4","type":"Clip"}]"#)
        #expect(Display.trailer(other) == nil)
    }

    @Test func peopleCanBeTextsOrObjects() throws {
        let people = try list(#"["Tim Robbins", {"name":"Morgan Freeman"}, "", 3, "Tim Robbins"]"#)
        #expect(Display.people(people) == ["Tim Robbins", "Morgan Freeman", "3"])
        #expect(Display.people(people, limit: 1) == ["Tim Robbins"])
    }
}
