import Foundation

/// Finds a catalog for the "More like this" row of a title.
public enum Similar {
    /// The first catalog of the same type that can filter by one of the `genres` of the title.
    /// A catalog where the genre is a choice comes before one where it is required, because a
    /// required genre is often a list of the newest titles only. A catalog that needs other
    /// values, such as a search, is left out.
    public static func row(_ addons: [Addon], type: String, genres: [String]) -> CatalogRow? {
        let candidates = addons
            .flatMap { a in a.manifest.catalogs.map { (a, $0) } }
            .filter { same($0.1.type, type) }
            .filter { pair in !pair.1.extras.contains { $0.isRequired && $0.name != "genre" } }
            .enumerated()
            // The offset keeps the order of the source list inside each group.
            .sorted { (rank($0.element.1), $0.offset) < (rank($1.element.1), $1.offset) }
            .map(\.element)
        for genre in genres {
            for (addon, catalog) in candidates {
                let options = catalog.extras.first { $0.name == "genre" }?.options ?? []
                if let option = options.first(where: { same($0, genre) }) {
                    return CatalogRow(addon: addon, catalog: catalog, extras: [("genre", option)])
                }
            }
        }
        return nil
    }

    /// 1 for a catalog where the genre is required, 0 for the others.
    private static func rank(_ catalog: Catalog) -> Int {
        catalog.extras.contains { $0.name == "genre" && $0.isRequired } ? 1 : 0
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        a.caseInsensitiveCompare(b) == .orderedSame
    }
}
