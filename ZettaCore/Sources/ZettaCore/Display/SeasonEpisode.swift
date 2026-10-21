import Foundation

extension Display {
    /// Reads the season and the episode from a video ID such as `tt0903747:1:2` or `kitsu:1376:5`.
    public static func seasonEpisode(_ videoId: String) -> (season: Int?, episode: Int?) {
        let parts = videoId.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if parts[0].hasPrefix("tt") && parts.count >= 3 { return (Int(parts[1]), Int(parts[2])) }
        if parts.count >= 3 { return (nil, Int(parts[parts.count - 1])) }
        return (nil, nil)
    }
}
