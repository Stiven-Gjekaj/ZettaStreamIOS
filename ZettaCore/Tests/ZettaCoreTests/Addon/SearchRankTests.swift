import Foundation
import Testing
@testable import ZettaCore

struct SearchRankTests {
    private func m(_ id: String, _ name: String, _ type: String = "series", year: String? = "2020", imdb: String? = nil, poster: String? = nil) -> MetaPreview {
        var meta = MetaPreview(id: id, type: type, name: name)
        meta.poster = poster
        meta.releaseInfo = year
        meta.imdbId = imdb
        return meta
    }

    @Test func theSameShowFromThreeAddonsIsOneEntryAtTheTop() throws {
        let first = [m("tt37376994", "Ted Lasso Does Comic Relief", "movie", year: "2022"), m("tmdb:1", "Ted Lasso: The Richmond Way")]
        let second = [m("tmdb:97546", "Ted Lasso", imdb: "tt10986410", poster: "https://p.test/a.jpg")]
        let third = [m("tt10986410", "Ted Lasso", year: "2020-2023"), m("x:9", "Ted Lasso", year: "2020")]
        let result = SearchRank.merge(query: "ted lasso", answers: [first, second, third])
        let top = try #require(result.first)
        #expect(top.id == "tt10986410")
        #expect(top.poster == "https://p.test/a.jpg")
        #expect(result.filter { $0.name == "Ted Lasso" }.count == 1)
        #expect(result.count == 3)
    }

    @Test func twoShowsWithOneNameButOtherYearsStayApart() {
        let result = SearchRank.merge(query: "dune", answers: [[m("a:1", "Dune", "movie", year: "1984"), m("b:1", "Dune", "movie", year: "2021")]])
        #expect(result.count == 2)
        let noYear = SearchRank.merge(query: "dune", answers: [[m("a:1", "Dune", "movie", year: nil)], [m("b:1", "Dune", "movie", year: nil)]])
        #expect(noYear.count == 2)
    }

    @Test func theBestMatchComesFirst() {
        let result = SearchRank.merge(
            query: "one piece",
            answers: [[m("1", "Piece of One"), m("2", "One Piece Film: Red", "movie"), m("3", "Someone Piecemeal"), m("4", "One Piece")]]
        )
        #expect(result.map(\.id) == ["4", "2", "1", "3"])
    }

    @Test func accentsCaseAndSignsDoNotMatter() {
        #expect(SearchRank.normalize("Pokémon: The Movie!") == "pokemon the movie")
        #expect(SearchRank.normalize("  Fast & Furious  ") == "fast and furious")
        #expect(SearchRank.score("POKEMON the movie", m("1", "Pokémon: The Movie")) == 100)
        var titan = MetaPreview(id: "1", type: "anime", name: "Shingeki no Kyojin")
        titan.aliases = ["Attack on Titan"]
        #expect(SearchRank.score("attack on titan", titan) == 100)
    }
}

struct SearchRankSpeedTests {
    private func answers(_ addons: Int) -> [[MetaPreview]] {
        (0..<addons).map { a in
            (0..<100).map { i in
                var meta = MetaPreview(id: "a\(a):\(i)", type: i % 2 == 0 ? "movie" : "series", name: "Title \(a) number \(i) of the long list")
                meta.releaseInfo = "\(2000 + i % 20)"
                return meta
            }
        }
    }

    /// The shortest of a few runs, so that a pause of the machine does not count.
    private func time(_ input: [[MetaPreview]]) -> UInt64 {
        for _ in 0..<3 { _ = SearchRank.merge(query: "title", answers: input) }
        return (0..<5).map { _ in
            let start = DispatchTime.now().uptimeNanoseconds
            _ = SearchRank.merge(query: "title", answers: input)
            return DispatchTime.now().uptimeNanoseconds - start
        }.min() ?? 0
    }

    /// Four times the results take about four times the time. A merge that compares each
    /// result with each other result takes about sixteen times the time, and it stops the
    /// app with a long source list. A ratio does not depend on the speed of the machine.
    @Test func theTimeGrowsWithTheResultsAndNotWithTheirSquare() {
        let small = time(answers(10))
        let large = time(answers(40))
        let ratio = Double(large) / Double(max(small, 1))
        #expect(ratio < 9, "4 times the results took \(ratio) times the time")
    }
}
