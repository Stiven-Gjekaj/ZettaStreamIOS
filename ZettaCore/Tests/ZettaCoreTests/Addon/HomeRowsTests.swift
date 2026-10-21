import Testing
@testable import ZettaCore

struct HomeRowsTests {
    private func addon(_ name: String, _ catalogs: Catalog...) -> Addon {
        var manifest = Manifest(id: name, name: name)
        manifest.catalogs = catalogs
        return Addon(manifestUrl: "https://\(name).test/manifest.json", manifest: manifest)
    }

    private var cinemeta: Addon {
        addon(
            "cinemeta",
            Catalog(type: "movie", id: "top", name: "Popular", extras: [CatalogExtra(name: "genre", options: ["Action"])]),
            Catalog(type: "movie", id: "year", name: "New", extras: [CatalogExtra(name: "genre", isRequired: true, options: ["2026", "2025"])]),
            Catalog(type: "series", id: "last", name: "Last videos", extras: [CatalogExtra(name: "lastVideosIds", isRequired: true)]),
            Catalog(type: "movie", id: "find", name: "Search", extras: [CatalogExtra(name: "search", isRequired: true)])
        )
    }

    @Test func aRequiredChoiceTakesTheFirstOptionAndFreeTextGetsNoRow() {
        let rows = HomeRows.of(cinemeta)
        #expect(rows.map(\.title) == ["Popular", "New 2026"])
        #expect(rows[1].extras.map { "\($0.0)=\($0.1)" } == ["genre=2026"])
        #expect(rows[1].key.hasSuffix("|genre=2026"))
    }

    @Test func newRowsComeFirstAndTheAddonOrderStaysInsideATier() {
        let anime = addon(
            "anime",
            Catalog(type: "anime", id: "rated", name: "Top Rated"),
            Catalog(type: "anime", id: "airing", name: "Currently Airing"),
            Catalog(type: "anime", id: "x", name: "Genres")
        )
        let ordered = HomeRows.order(HomeRows.of(cinemeta) + HomeRows.of(anime))
        #expect(ordered.map(\.title) == ["New 2026", "Currently Airing", "Popular", "Top Rated", "Genres"])
    }

    @Test func aRowThatRepeatsARowAboveIsARepeat() {
        let above = [["a", "b", "c", "d", "e"]]
        #expect(HomeRows.isRepeat(["a", "b", "c", "d", "x"], above: above))
        #expect(!HomeRows.isRepeat(["a", "x", "y", "z", "w"], above: above))
        #expect(!HomeRows.isRepeat(["a", "b"], above: above))
    }

    @Test func theViewerOrderComesFirstAndANewRowGoesLast() throws {
        let anime = addon("anime", Catalog(type: "anime", id: "rated", name: "Top Rated"), Catalog(type: "anime", id: "x", name: "Genres"))
        let rows = HomeRows.of(cinemeta) + HomeRows.of(anime)
        let keys = Dictionary(uniqueKeysWithValues: rows.map { ($0.title, $0.key) })
        let order = [try #require(keys["Genres"]), try #require(keys["Popular"]), "gone|row"]
        #expect(HomeRows.arrange(rows, keys: order).map(\.title) == ["Genres", "Popular", "New 2026", "Top Rated"])
    }

    @Test func aMoveSwapsARowWithItsNeighbourAndStopsAtTheEnds() {
        let rows = HomeRows.of(cinemeta)
        let keys = rows.map(\.key)
        #expect(HomeRows.move(rows, index: 1, step: -1) == keys.reversed())
        #expect(HomeRows.move(rows, index: 0, step: -1) == keys)
        #expect(HomeRows.move(rows, index: 1, step: 1) == keys)
    }
}
