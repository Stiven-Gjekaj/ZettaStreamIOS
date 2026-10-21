import Testing
@testable import ZettaCore

struct EpisodesTests {
    private func show(_ videos: [Video]) -> Meta {
        var meta = Meta(preview: MetaPreview(id: "tt1", type: "series", name: "Show"))
        meta.videos = videos
        return meta
    }

    private func progress(_ id: String, position: Int, duration: Int, updated: Int) -> WatchProgress {
        WatchProgress(videoId: id, meta: MetaPreview(id: "tt1", type: "series"), label: id,
                      position: position, duration: duration, updated: updated)
    }

    private let s1e1 = Video(id: "tt1:1:1", season: 1, episode: 1)
    private let s1e2 = Video(id: "tt1:1:2", season: 1, episode: 2)
    private let s2e1 = Video(id: "tt1:2:1", season: 2, episode: 1)
    private let special = Video(id: "tt1:0:1", season: 0, episode: 1)
    private let other = Video(id: "tt1:x", title: "Extra")

    @Test func specialsGoLastAndAnEpisodeWithNoSeasonGoesBeforeThem() {
        #expect(Episodes.sorted([special, s2e1, other, s1e2, s1e1]).map(\.id) == [s1e1, s1e2, s2e1, other, special].map(\.id))
        #expect(Episodes.seasons([special, s2e1, other, s1e2, s1e1]) == [1, 2, nil, 0])
    }

    @Test func playStartsTheFirstEpisodeThatIsNotWatched() {
        let data = LibraryData(watched: [s1e1.id])
        #expect(Episodes.nextToPlay(show([special, s1e2, s1e1]), data)?.id == s1e2.id)
    }

    @Test func playSkipsTheSpecialsWhenTheOtherEpisodesAreWatched() {
        let data = LibraryData(watched: [s1e1.id, s1e2.id])
        // All episodes are watched, so Play starts the first one.
        #expect(Episodes.nextToPlay(show([special, s1e2, s1e1]), data)?.id == s1e1.id)
    }

    @Test func playResumesTheEpisodeThatTheViewerWatchedLast() {
        let data = LibraryData(progress: [
            s1e1.id: progress(s1e1.id, position: 1000, duration: 100_000, updated: 5),
            s2e1.id: progress(s2e1.id, position: 1000, duration: 100_000, updated: 9),
        ])
        #expect(Episodes.nextToPlay(show([s1e1, s1e2, s2e1]), data)?.id == s2e1.id)
    }

    @Test func aFinishedEpisodeDoesNotResume() {
        let data = LibraryData(progress: [s1e1.id: progress(s1e1.id, position: 95_000, duration: 100_000, updated: 9)],
                               watched: [s1e1.id])
        #expect(!Episodes.resumes(data.progress[s1e1.id]))
        #expect(Episodes.nextToPlay(show([s1e1, s1e2]), data)?.id == s1e2.id)
    }

    @Test func theLabelHasTheNumberWhenTheAddonGivesIt() {
        #expect(Episodes.label(Video(id: "a", title: "Pilot", season: 1, episode: 2)) == "S1 E2  Pilot")
        #expect(Episodes.label(other) == "Extra")
        #expect(Episodes.seasonName(nil) == "Other")
        #expect(Episodes.seasonName(0) == "Specials")
        #expect(Episodes.seasonName(3) == "Season 3")
    }
}
