import Testing
@testable import ZettaCore

struct CatalogPagingTests {
    private let addon = Addon(manifestUrl: "https://a.test/manifest.json", manifest: Manifest(id: "a", name: "A"))
    private var paged: CatalogRow {
        CatalogRow(
            addon: addon,
            catalog: Catalog(type: "movie", id: "top", name: "Popular", extras: [CatalogExtra(name: "genre"), CatalogExtra(name: "skip")]),
            extras: [("genre", "Drama")]
        )
    }

    private func t(_ id: String) -> MetaPreview { MetaPreview(id: id, type: "movie", name: id) }

    @Test func theNextPageSkipsTheLoadedTitlesAndKeepsTheOtherValues() {
        #expect(CatalogPaging.canPage(paged))
        #expect(CatalogPaging.page(paged, loaded: 0) == paged)
        #expect(CatalogPaging.page(paged, loaded: 48).extras.map { "\($0.0)=\($0.1)" } == ["genre=Drama", "skip=48"])
        // The next page replaces the old skip value.
        #expect(CatalogPaging.page(CatalogPaging.page(paged, loaded: 48), loaded: 96).extras.map { "\($0.0)=\($0.1)" } == ["genre=Drama", "skip=96"])
        #expect(!CatalogPaging.canPage(CatalogRow(addon: addon, catalog: Catalog(type: "movie", id: "x", name: "X"))))
    }

    @Test func aPageAddsOnlyNewTitlesAndAnEmptyOrRepeatedPageEnds() {
        let (first, more) = CatalogPaging.add([], page: [t("1"), t("2")])
        #expect(more)
        let (second, more2) = CatalogPaging.add(first, page: [t("2"), t("3")])
        #expect(second.map(\.id) == ["1", "2", "3"])
        #expect(more2)
        #expect(!CatalogPaging.add(second, page: [t("1"), t("3")]).more)
        #expect(!CatalogPaging.add(second, page: []).more)
    }
}
