import Foundation

/// How the home screen gets its rows from the catalogs of the addons.
public enum HomeRows {
    /// Makes the rows of one addon. A catalog that needs a choice from a list,
    /// such as Cinemeta "New" with a year, gets the first choice, which is the
    /// newest. A catalog that needs free text, such as a search, gets no row.
    public static func of(_ addon: Addon) -> [CatalogRow] {
        addon.manifest.catalogs.compactMap { catalog in
            let required = catalog.extras.filter(\.isRequired)
            if required.isEmpty { return CatalogRow(addon: addon, catalog: catalog) }
            guard required.allSatisfy({ !$0.options.isEmpty }) else { return nil }
            // A name that shows two times keeps its first place and its last value, as a map does.
            var extras: [(String, String)] = []
            for extra in required {
                if let index = extras.firstIndex(where: { $0.0 == extra.name }) { extras[index].1 = extra.options[0] }
                else { extras.append((extra.name, extra.options[0])) }
            }
            return CatalogRow(addon: addon, catalog: catalog, extras: extras)
        }
    }

    private static let newWords = try! NSRegularExpression(
        pattern: #"\b(new|latest|recent|trending|airing|season|releases?|now|today|live)\b"#, options: .caseInsensitive)
    private static let popularWords = try! NSRegularExpression(
        pattern: #"\b(popular|top|featured|rated|best)\b"#, options: .caseInsensitive)

    /// 0 for new and trending rows, 1 for popular rows, 2 for the others.
    public static func tier(_ row: CatalogRow) -> Int {
        let title = row.title
        let range = NSRange(title.startIndex..., in: title)
        if newWords.firstMatch(in: title, range: range) != nil { return 0 }
        if popularWords.firstMatch(in: title, range: range) != nil { return 1 }
        return 2
    }

    /// Puts the rows in order: by `tier`, then in the order of the source list.
    /// The sort is stable, so it keeps the order of the addons inside each tier.
    public static func order(_ rows: [CatalogRow]) -> [CatalogRow] {
        stableSorted(rows, by: tier)
    }

    /// Puts `rows` in the order of `keys`. The rows that `keys` does not name, such as the
    /// rows of a new addon, keep their order and come after the others.
    public static func arrange(_ rows: [CatalogRow], keys: [String]) -> [CatalogRow] {
        var place: [String: Int] = [:]
        for (i, key) in keys.enumerated() { place[key] = i }
        return stableSorted(rows) { place[$0.key] ?? Int.max }
    }

    /// The order after the row at `index` moves one place up (`step` -1) or down (`step` 1).
    public static func move(_ rows: [CatalogRow], index: Int, step: Int) -> [String] {
        var keys = rows.map(\.key)
        let target = index + step
        guard keys.indices.contains(index), keys.indices.contains(target) else { return keys }
        keys.insert(keys.remove(at: index), at: target)
        return keys
    }

    /// Tells if `items` mostly repeat the items of a row above. Two addons often
    /// give the same "Popular" list, and the second copy does not help.
    public static func isRepeat(_ items: [String], above: [[String]], limit: Double = 0.7) -> Bool {
        guard items.count >= 4 else { return false }
        let mine = Set(items)
        return above.contains { other in
            guard !other.isEmpty else { return false }
            let theirs = Set(other)
            return Double(mine.filter(theirs.contains).count) >= Double(mine.count) * limit
        }
    }

    /// A sort that keeps the order of two items with the same value.
    /// The sort of the standard library does not promise this.
    private static func stableSorted(_ rows: [CatalogRow], by value: (CatalogRow) -> Int) -> [CatalogRow] {
        rows.enumerated()
            .map { (value($0.element), $0.offset, $0.element) }
            .sorted { ($0.0, $0.1) < ($1.0, $1.1) }
            .map(\.2)
    }
}
