import Foundation
import Testing
@testable import ZettaCore

struct NewEpisodesTests {
    private let now = NewEpisodes.time("2026-10-14T12:00:00Z")!

    private func show(_ id: String, _ episodes: (String, String?)...) -> Meta {
        var meta = Meta(preview: MetaPreview(id: id, type: "series", name: id))
        meta.videos = episodes.map { id, date in
            var video = Video(id: id)
            video.released = date
            return video
        }
        return meta
    }

    @Test func eachShowGivesItsNewestEpisodeOfTheWeek() {
        let a = show("a", ("a:1:1", "2026-10-01T00:00:00Z"), ("a:1:2", "2026-10-09T00:00:00Z"), ("a:1:3", "2026-10-13T00:00:00Z"))
        let b = show("b", ("b:1:5", "2026-10-12T00:00:00Z"), ("b:1:6", "2026-10-20T00:00:00Z"))
        let c = show("c", ("c:1:1", "2026-09-01T00:00:00Z"), ("c:1:2", nil))
        let found = NewEpisodes.find([a, b, c], now: now, watched: [])
        #expect(found.map(\.video.id) == ["a:1:3", "b:1:5"])
    }

    @Test func aWatchedEpisodeIsNotNew() {
        let a = show("a", ("a:1:2", "2026-10-09T00:00:00Z"), ("a:1:3", "2026-10-13T00:00:00Z"))
        #expect(NewEpisodes.find([a], now: now, watched: ["a:1:3"]).map(\.video.id) == ["a:1:2"])
    }

    @Test func theFollowedShowsAreTheWatchlistAndTheHistoryWithNoFilms() {
        let data = LibraryData(
            watchlist: [MetaPreview(id: "s1", type: "series", name: "One"), MetaPreview(id: "m1", type: "movie", name: "Film")],
            progress: [
                "s2:1:1": WatchProgress(videoId: "s2:1:1", meta: MetaPreview(id: "s2", type: "anime", name: "Two"), label: "E1",
                                        position: 10, duration: 100, updated: 2),
                "s1:1:1": WatchProgress(videoId: "s1:1:1", meta: MetaPreview(id: "s1", type: "series", name: "One"), label: "E1",
                                        position: 10, duration: 100, updated: 1),
            ]
        )
        #expect(NewEpisodes.followed(data).map(\.id) == ["s1", "s2"])
    }

    @Test func theFollowedShowsStopAtTheLimit() {
        let data = LibraryData(watchlist: (1...30).map { MetaPreview(id: "s\($0)", type: "Series") })
        #expect(NewEpisodes.followed(data).count == NewEpisodes.maxShows)
    }

    @Test func aShowWithOneDateForEachEpisodeIsLeftOut() {
        let fake = show("f", ("f:1:1", "2026-10-14T10:00:00.000Z"), ("f:1:2", "2026-10-14T10:00:00.000Z"))
        let single = show("s", ("s:1:1", "2026-10-14T10:00:00.000Z"))
        #expect(NewEpisodes.find([fake, single], now: now, watched: []).map(\.video.id) == ["s:1:1"])
    }

    @Test func aTimeReadsFractionalSecondsAndRefusesOtherText() {
        #expect(NewEpisodes.time("2026-10-14T10:00:00.250Z") == NewEpisodes.time("2026-10-14T10:00:00Z")! + 250)
        #expect(NewEpisodes.time("2026-10-14") == nil)
        #expect(NewEpisodes.time("soon") == nil)
    }
}
