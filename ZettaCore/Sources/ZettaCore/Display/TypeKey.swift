import Foundation

extension Display {
    /// One key for types that mean the same thing. Addons write "sport" and
    /// "sports", or "tv" and "channel", so the filter shows each kind one time.
    public static func typeKey(_ type: String) -> String {
        let t = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch t {
        case "sport", "sports", "events": return "sport"
        case "tv", "channel", "channels": return "tv"
        case "movies", "film", "films": return "movie"
        case "show", "shows", "tvshow": return "series"
        default: return t
        }
    }

    /// The name of a type filter. Nil is the filter that shows all types.
    public static func typeLabel(_ type: String?) -> String {
        guard let type else { return "All" }
        switch typeKey(type) {
        case "movie": return "Movies"
        case "series": return "Series"
        case "anime": return "Anime"
        case "tv": return "TV channels"
        case "sport": return "Sports"
        default: return type.prefix(1).uppercased() + type.dropFirst()
        }
    }
}
