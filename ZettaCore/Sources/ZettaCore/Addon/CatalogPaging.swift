import Foundation

/// Loads a catalog one page at a time, with the `skip` value of Stremio addons.
public enum CatalogPaging {
    /// True when the catalog accepts `skip`, so it can give more than its first page.
    public static func canPage(_ row: CatalogRow) -> Bool {
        row.catalog.extras.contains { $0.name == "skip" }
    }

    /// The row for the page after `loaded` titles.
    public static func page(_ row: CatalogRow, loaded: Int) -> CatalogRow {
        loaded == 0 ? row : row.setting("skip", to: String(loaded))
    }

    /// Adds a new page to the titles. A title that is there already does not come twice.
    /// There is more only when the page gave at least one new title.
    public static func add(_ titles: [MetaPreview], page: [MetaPreview]) -> (titles: [MetaPreview], more: Bool) {
        var known = Set(titles.map { $0.type + $0.id })
        let fresh = page.filter { known.insert($0.type + $0.id).inserted }
        return (titles + fresh, !fresh.isEmpty)
    }
}
