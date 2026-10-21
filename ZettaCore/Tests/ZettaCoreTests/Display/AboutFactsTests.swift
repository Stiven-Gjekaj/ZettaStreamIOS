import Foundation
import Testing
@testable import ZettaCore

struct AboutFactsTests {
    private func facts(_ meta: Meta) -> [String] {
        Display.aboutFacts(meta).map { "\($0.label)=\($0.value)" }
    }

    @Test func aSeriesShowsItsSeasonsAndEpisodes() {
        var preview = MetaPreview(id: "tt1", type: "series", name: "Show")
        preview.releaseInfo = "2019-2023"
        preview.imdbRating = "8.4"
        preview.genres = ["Drama", "Crime"]
        var meta = Meta(preview: preview)
        meta.videos = [Video(id: "a", season: 0, episode: 1), Video(id: "b", season: 1, episode: 1), Video(id: "c", season: 2, episode: 1)]
        #expect(facts(meta) == [
            "Type=Series", "Released=2019-2023", "IMDb=8.4 / 10", "Genres=Drama, Crime",
            "Seasons=2", "Episodes=3",
        ])
    }

    @Test func aFilmShowsNoEpisodesAndAMissingFactDoesNotShow() throws {
        var preview = MetaPreview(id: "tt2", type: "movie", name: "Film")
        preview.aliases = ["Film", "Le Film"]
        var meta = Meta(preview: preview)
        meta.runtime = "118 min"
        meta.videos = [Video(id: "tt2")]
        meta.cast = try #require(try JSONValue.parse(Data(#"["Ann", "Bo"]"#.utf8)).arrayValue)
        #expect(facts(meta) == ["Type=Movie", "Runtime=118 min", "Cast=Ann, Bo", "Other names=Le Film"])
    }
}
