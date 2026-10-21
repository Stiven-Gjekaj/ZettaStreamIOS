import Testing
@testable import ZettaCore

struct SeasonEpisodeTests {
    @Test func readsTheSeasonAndTheEpisodeFromAVideoId() {
        let series = Display.seasonEpisode("tt0903747:1:2")
        #expect(series.season == 1 && series.episode == 2)
        let anime = Display.seasonEpisode("kitsu:1376:5")
        #expect(anime.season == nil && anime.episode == 5)
        let film = Display.seasonEpisode("tt0111161")
        #expect(film.season == nil && film.episode == nil)
        let empty = Display.seasonEpisode("")
        #expect(empty.season == nil && empty.episode == nil)
    }
}
