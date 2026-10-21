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
}
