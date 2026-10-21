import Foundation

/// A catalog row on the home screen.
public struct CatalogRow: Hashable, Sendable {
    public let addon: Addon
    public let catalog: Catalog
    /// The values of the extras, in the order that the request sends them.
    public let extras: [(String, String)]

    public init(addon: Addon, catalog: Catalog, extras: [(String, String)] = []) {
        self.addon = addon
        self.catalog = catalog
        self.extras = extras
    }

    public var key: String {
        "\(addon.manifestUrl)|\(catalog.type)|\(catalog.id)" + extras.map { "|\($0.0)=\($0.1)" }.joined()
    }

    /// The name of the row, with the choice it uses, for example "New 2026".
    public var title: String { ([catalog.name] + extras.map(\.1)).joined(separator: " ") }

    /// The value of the extra `name`, or nil.
    public func extra(_ name: String) -> String? { extras.first { $0.0 == name }?.1 }

    /// A copy with `name` set to `value`. A value that is there already keeps its place.
    public func setting(_ name: String, to value: String) -> CatalogRow {
        var copy = extras
        if let index = copy.firstIndex(where: { $0.0 == name }) { copy[index].1 = value } else { copy.append((name, value)) }
        return CatalogRow(addon: addon, catalog: catalog, extras: copy)
    }

    public static func == (a: CatalogRow, b: CatalogRow) -> Bool {
        a.addon == b.addon && a.catalog == b.catalog && a.extras.elementsEqual(b.extras) { $0 == $1 }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(addon)
        hasher.combine(catalog)
        for (name, value) in extras {
            hasher.combine(name)
            hasher.combine(value)
        }
    }
}
