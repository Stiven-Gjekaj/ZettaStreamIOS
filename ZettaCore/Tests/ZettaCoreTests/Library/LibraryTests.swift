import Foundation
import Testing
@testable import ZettaCore

/// A clock that a test sets by hand.
final class TestClock: @unchecked Sendable {
    var now = 0
}

struct LibraryTests {
    private let file: URL
    private let clock = TestClock()
    private let show = MetaPreview(id: "tt1", type: "series", name: "Show")
    private let film = MetaPreview(id: "tt2", type: "movie", name: "Film")

    init() throws {
        file = try temporaryFolder().appendingPathComponent("library.json")
    }

    private func library() -> Library {
        let clock = clock
        return Library(file: file) { clock.now }
    }

    @Test func theWatchlistTogglesAndStaysAfterARestart() throws {
        let library = library()
        try library.toggleWatchlist(show)
        #expect(self.library().isInWatchlist("tt1"))
        try library.toggleWatchlist(show)
        #expect(!self.library().isInWatchlist("tt1"))
    }

    @Test func aNewTitleGoesToTheTopOfTheWatchlist() throws {
        let library = library()
        try library.toggleWatchlist(show)
        try library.toggleWatchlist(film)
        #expect(library.data.watchlist.map(\.id) == ["tt2", "tt1"])
    }

    @Test func continueWatchingShowsTheNewestUnfinishedVideoOfEachTitle() throws {
        let library = library()
        clock.now = 1; try library.saveProgress(videoId: "tt1:1:1", meta: show, label: "E1", position: 100, duration: 1000)
        clock.now = 2; try library.saveProgress(videoId: "tt2", meta: film, label: "Film", position: 50, duration: 1000)
        clock.now = 3; try library.saveProgress(videoId: "tt1:1:2", meta: show, label: "E2", position: 200, duration: 1000)
        clock.now = 4; try library.saveProgress(videoId: "tt3", meta: MetaPreview(id: "tt3", type: "movie"), label: "Done", position: 950, duration: 1000)
        #expect(library.continueWatching().map(\.videoId) == ["tt1:1:2", "tt2"])
    }

    @Test func aVideoAtTheStartIsNotInContinueWatching() throws {
        let library = library()
        try library.saveProgress(videoId: "tt2", meta: film, label: "Film", position: 0, duration: 1000)
        #expect(library.continueWatching().isEmpty)
        #expect(library.progress("tt2")?.position == 0)
    }

    @Test func aVideoIsWatchedAfterNinetyPercent() throws {
        let library = library()
        try library.saveProgress(videoId: "tt2", meta: film, label: "Film", position: 899, duration: 1000)
        #expect(!library.isWatched("tt2"))
        try library.saveProgress(videoId: "tt2", meta: film, label: "Film", position: 900, duration: 1000)
        #expect(library.isWatched("tt2"))
        try library.toggleWatched("tt2")
        #expect(!library.isWatched("tt2"))
    }

    @Test func aVideoWithNoDurationIsNeverFinished() {
        #expect(!WatchProgress(videoId: "a", meta: film, label: "", position: 10, duration: 0, updated: 0).isFinished)
    }

    @Test func aDamagedFileGivesAnEmptyLibrary() throws {
        try Data("{not json".utf8).write(to: file)
        #expect(library().data == LibraryData())
    }

    @Test func markWatchedDoesNotRemoveAMark() throws {
        let library = library()
        try library.markWatched("tt1:1:1")
        try library.markWatched("tt1:1:1")
        #expect(self.library().isWatched("tt1:1:1"))
    }

    @Test func aFavouriteChannelTogglesAndStaysAfterARestart() throws {
        #expect(try library().toggleFavoriteChannel("rtsh1.al"))
        #expect(library().data.favoriteChannels == ["rtsh1.al"])
        #expect(try !library().toggleFavoriteChannel("rtsh1.al"))
        #expect(library().data.favoriteChannels.isEmpty)
    }

    @Test func clearHistoryKeepsTheWatchlistAndTheFavourites() throws {
        let library = library()
        try library.toggleWatchlist(show)
        try library.toggleFavoriteChannel("news24al")
        try library.saveProgress(videoId: "tt2", meta: film, label: "Film", position: 950, duration: 1000)
        try library.clearHistory()
        #expect(library.data == LibraryData(watchlist: [show], favoriteChannels: ["news24al"]))
    }

    @Test func anObserverSeesAChange() async throws {
        let library = library()
        var updates = library.updates().makeAsyncIterator()
        #expect(await updates.next()?.watchlist == [])
        try library.toggleWatchlist(show)
        #expect(await updates.next()?.watchlist.map(\.id) == ["tt1"])
    }
}
