import Foundation

extension Display {
    private static let seasonSuffix = try! NSRegularExpression(
        pattern: #"\s*(:\s*)?(Season\s*\d+|\d+(st|nd|rd|th)\s+Season|Part\s*\d+)$"#, options: .caseInsensitive)

    /// Removes "Season 2", "2nd Season", or "Part 2" from the end of a name.
    /// The detail screen uses it to open the full series of one season.
    public static func withoutSeasonSuffix(_ name: String) -> String {
        seasonSuffix.stringByReplacingMatches(in: name, range: NSRange(name.startIndex..., in: name), withTemplate: "")
    }
}
