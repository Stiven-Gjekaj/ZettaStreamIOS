import Testing
@testable import ZettaCore

struct SimilarTests {
    private var cinemeta: Addon {
        var manifest = Manifest(id: "c", name: "C")
        manifest.catalogs = [
            Catalog(type: "movie", id: "year", name: "New", extras: [CatalogExtra(name: "genre", isRequired: true, options: ["2026", "Drama"])]),
            Catalog(type: "movie", id: "top", name: "Popular", extras: [CatalogExtra(name: "genre", options: ["Action", "Drama"]), CatalogExtra(name: "search")]),
            Catalog(type: "movie", id: "find", name: "Search", extras: [CatalogExtra(name: "search", isRequired: true), CatalogExtra(name: "genre", options: ["Crime"])]),
            Catalog(type: "series", id: "top", name: "Popular", extras: [CatalogExtra(name: "genre", options: ["Crime"])]),
        ]
        return Addon(manifestUrl: "https://c.test/manifest.json", manifest: manifest)
    }

    @Test func aCatalogWithAChosenGenreComesFirst() throws {
        let row = try #require(Similar.row([cinemeta], type: "movie", genres: ["drama"]))
        #expect(row.catalog.id == "top")
        #expect(row.extras.map { "\($0.0)=\($0.1)" } == ["genre=Drama"])
    }

    @Test func theNextGenreIsTriedAndOtherTypesAndSearchesAreLeftOut() {
        #expect(Similar.row([cinemeta], type: "movie", genres: ["Mystery", "Action"])?.extra("genre") == "Action")
        #expect(Similar.row([cinemeta], type: "movie", genres: ["Crime"]) == nil)
        #expect(Similar.row([cinemeta], type: "anime", genres: ["Drama"]) == nil)
    }
}
