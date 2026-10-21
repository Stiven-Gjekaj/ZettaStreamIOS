import Foundation

/// Keeps the last searches, newest first. A search that is there already moves to the top.
public enum SearchHistory {
    public static let max = 8

    public static func add(_ history: [String], _ query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return history }
        let key = q.lowercased()
        return Array(([q] + history.filter { $0.lowercased() != key }).prefix(max))
    }
}
