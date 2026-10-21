import Foundation

/// Puts search results from many addons in one list: the same title from two addons
/// becomes one entry, and the titles that match the search best come first.
public enum SearchRank {
    /// A title with the number of addons that gave it.
    private struct Entry {
        var meta: MetaPreview
        var sources: Int
        let order: Int
    }

    /// `answers` has one list for each addon, in the order of the source list.
    /// Two entries are one title when they have the same ID or IMDb ID, or the same
    /// name, kind, and first year. The entry with an IMDb ID stays, because most
    /// stream addons know that ID. Each result is looked up in tables, not compared
    /// with each other result, so a long list stays fast.
    public static func merge(query: String, answers: [[MetaPreview]]) -> [MetaPreview] {
        var names: [String: String] = [:]
        func norm(_ text: String) -> String {
            if let known = names[text] { return known }
            let normal = normalize(text)
            names[text] = normal
            return normal
        }
        var entries: [Entry] = []
        var byId: [String: Int] = [:]
        var byImdb: [String: Int] = [:]
        var byName: [String: Int] = [:]
        func nameKey(_ m: MetaPreview) -> String? {
            Display.year(m.releaseInfo).map { "\(kind(m))|\(norm(m.name))|\($0)" }
        }
        func index(_ entry: Int, _ m: MetaPreview) {
            byId[m.id] = entry
            if let i = imdb(m), byImdb[i] == nil { byImdb[i] = entry }
            if let key = nameKey(m), byName[key] == nil { byName[key] = entry }
        }
        for answer in answers {
            var seen = Set<String>()
            for meta in answer where seen.insert(meta.type + meta.id).inserted {
                let i = imdb(meta)
                let byNameMatch = nameKey(meta).flatMap { byName[$0] }
                // A match by name only counts when the IMDb IDs do not say that the titles differ.
                let same = byId[meta.id] ?? i.flatMap { byImdb[$0] }
                    ?? byNameMatch.flatMap { e in (imdb(entries[e].meta) == nil || i == nil) ? e : nil }
                if let same {
                    entries[same].sources += 1
                    let kept = entries[same].meta
                    entries[same].meta = !kept.id.hasPrefix("tt") && meta.id.hasPrefix("tt") ? fill(meta, with: kept) : fill(kept, with: meta)
                    index(same, meta)
                } else {
                    entries.append(Entry(meta: meta, sources: 1, order: entries.count))
                    index(entries.count - 1, meta)
                }
            }
        }
        // The score of each entry is found one time, not in each comparison of the sort.
        let q = norm(query)
        return entries
            .map { ($0, score(q, $0.meta, norm)) }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                if a.0.sources != b.0.sources { return a.0.sources > b.0.sources }
                return a.0.order < b.0.order
            }
            .map(\.0.meta)
    }

    /// How well the name of `meta` matches `query`: 100 for the same name, then less.
    public static func score(_ query: String, _ meta: MetaPreview) -> Int {
        score(normalize(query), meta, normalize)
    }

    private static func score(_ q: String, _ meta: MetaPreview, _ norm: (String) -> String) -> Int {
        if q.isEmpty { return 0 }
        let words = q.split(separator: " ", omittingEmptySubsequences: false)
        return ([meta.name] + meta.aliases).map { name in
            let n = norm(name)
            let nameWords = n.split(separator: " ", omittingEmptySubsequences: false)
            if n == q { return 100 }
            if n.hasPrefix(q + " ") { return 80 }
            if words.allSatisfy(nameWords.contains) { return 60 }
            if n.contains(q) { return 40 }
            if words.allSatisfy({ w in nameWords.contains { $0.hasPrefix(w) } }) { return 30 }
            return 0
        }.max() ?? 0
    }

    /// The form of a text for a comparison: no accents, lower case, and one space
    /// in place of each run of signs.
    public static func normalize(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        var gap = false
        let lower = text.decomposedStringWithCanonicalMapping.unicodeScalars
            .filter { !isMark($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
        for scalar in lower.unicodeScalars {
            if isLetterOrNumber(scalar) {
                if gap && !out.isEmpty { out.append(" ") }
                gap = false
                out.append(scalar)
            } else {
                gap = true
            }
        }
        return String(out)
    }

    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: return true
        default: return false
        }
    }

    private static func isLetterOrNumber(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber: return true
        default: return false
        }
    }

    private static func imdb(_ m: MetaPreview) -> String? {
        if m.id.hasPrefix("tt") { return m.id }
        return m.imdbId.flatMap { $0.hasPrefix("tt") ? $0 : nil }
    }

    /// A film is one kind. A series and an anime series are the other.
    private static func kind(_ m: MetaPreview) -> String {
        m.type.lowercased() == "movie" ? "movie" : "show"
    }

    /// Keeps `kept`, with the facts that only `other` has.
    private static func fill(_ kept: MetaPreview, with other: MetaPreview) -> MetaPreview {
        var copy = kept
        copy.poster = kept.poster ?? other.poster
        copy.background = kept.background ?? other.background
        copy.logo = kept.logo ?? other.logo
        copy.description = kept.description ?? other.description
        copy.releaseInfo = kept.releaseInfo ?? other.releaseInfo
        copy.imdbRating = kept.imdbRating ?? other.imdbRating
        copy.genres = kept.genres.isEmpty ? other.genres : kept.genres
        copy.imdbId = kept.imdbId ?? other.imdbId ?? (other.id.hasPrefix("tt") ? other.id : nil)
        return copy
    }
}
