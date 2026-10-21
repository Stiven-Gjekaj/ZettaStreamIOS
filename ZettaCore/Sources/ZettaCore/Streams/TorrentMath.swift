import Foundation

/// Pure helpers for the torrent engine. They are separate so that tests can use them.
public enum TorrentMath {
    /// Public trackers that help to find peers when the addon gives none.
    public static let defaultTrackers = [
        "udp://tracker.opentrackr.org:1337/announce",
        "udp://open.stealth.si:80/announce",
        "udp://tracker.torrent.eu.org:451/announce",
        "udp://exodus.desync.com:6969/announce",
        "udp://tracker.openbittorrent.com:6969/announce",
        "udp://open.demonii.com:1337/announce",
    ]

    private static let videoExtensions: Set = ["mkv", "mp4", "m4v", "avi", "webm", "mov", "ts", "m2ts", "wmv", "flv", "mpg", "mpeg"]

    public static func isInfoHash(_ text: String?) -> Bool {
        guard let text, text.unicodeScalars.count == 40 else { return false }
        return text.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) || "abcdefABCDEF".unicodeScalars.contains($0) }
    }

    /// The trackers of a torrent: the ones that the addon gives first, then the public ones, each one time.
    /// Stremio addons give trackers in `sources` as `tracker:udp://...`, and DHT nodes as `dht:...`, which this leaves out.
    public static func trackers(_ sources: [String]) -> [String] {
        var out: [String] = []
        for tracker in sources.filter({ $0.hasPrefix("tracker:") }).map({ String($0.dropFirst("tracker:".count)) }) + defaultTrackers
        where !out.contains(tracker) {
            out.append(tracker)
        }
        return out
    }

    /// Makes a magnet link with the hash, the name, and the trackers.
    public static func magnet(infoHash: String, sources: [String], name: String? = nil) -> String {
        var link = "magnet:?xt=urn:btih:" + infoHash.lowercased()
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { link += "&dn=" + formEncode(name) }
        for tracker in trackers(sources) { link += "&tr=" + formEncode(tracker) }
        return link
    }

    private static let formSafe = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-*_".utf8)

    /// Encodes as an HTML form does, like `URLEncoder` in Java: a space is a plus.
    static func formEncode(_ value: String) -> String {
        var out = ""
        for byte in value.utf8 {
            if formSafe.contains(byte) { out.append(Character(UnicodeScalar(byte))) }
            else if byte == UInt8(ascii: " ") { out.append("+") }
            else { out += String(format: "%%%02X", byte) }
        }
        return out
    }

    /// The part of a path after the last slash.
    private static func lastComponent(_ name: String) -> Substring {
        name.lastIndex(of: "/").map { name[name.index(after: $0)...] } ?? name[...]
    }

    /// The index of the largest file. The first one wins a tie.
    private static func largest(_ indices: [Int], _ sizes: [Int64]) -> Int {
        indices.max { sizes[$0] < sizes[$1] }!
    }

    /// Selects the file to play, in this order: the index that the addon gave
    /// when it is a video, the file with the name that the addon gave, the
    /// video with the episode number in its name, and the largest video.
    /// A season pack often has no index, so the name and the episode matter.
    /// Gives -1 when there is no file. `sizes` has one size for each name.
    public static func chooseFile(names: [String], sizes: [Int64], preferred: Int?, filename: String? = nil,
                                  season: Int? = nil, episode: Int? = nil) -> Int {
        if names.isEmpty { return -1 }
        if let preferred, names.indices.contains(preferred), isVideo(names[preferred]) { return preferred }
        let videos = names.indices.filter { isVideo(names[$0]) }
        if let filename {
            let wanted = lastComponent(filename).lowercased()
            if let match = videos.first(where: { lastComponent(names[$0]).lowercased() == wanted }) { return match }
        }
        if let episode {
            let matches = videos.filter { matchesEpisode(names[$0], season: season, episode: episode) }
            if !matches.isEmpty { return largest(matches, sizes) }
        }
        return largest(videos.isEmpty ? Array(names.indices) : videos, sizes)
    }

    /// Finds S01E02, 1x02, or " - 02" (the anime form) in a file name.
    public static func matchesEpisode(_ name: String, season: Int?, episode: Int) -> Bool {
        let n = String(lastComponent(name))
        let e = "0*\(episode)"
        var patterns: [String] = []
        if let season {
            patterns.append(#"(?i)s0*\#(season)[ ._-]*e\#(e)(?!\d)"#)
            patterns.append(#"(?i)(?<!\d)0*\#(season)x\#(e)(?!\d)"#)
        }
        patterns.append(#"(?i)(?:\s-\s|\be|\bep\.?\s?|episode\s)\#(e)(?!\d)"#)
        return patterns.contains { StreamRegex($0).matches(n) }
    }

    /// The extension of a name after its last dot, in lower case. Empty when there is no dot.
    private static func fileExtension(_ name: String) -> String {
        name.lastIndex(of: ".").map { name[name.index(after: $0)...].lowercased() } ?? ""
    }

    public static func isVideo(_ name: String) -> Bool {
        videoExtensions.contains(fileExtension(name))
    }

    public static func mimeType(_ name: String) -> String {
        switch fileExtension(name) {
        case "mkv": "video/x-matroska"
        case "mp4", "m4v", "mov": "video/mp4"
        case "webm": "video/webm"
        case "avi": "video/x-msvideo"
        case "ts", "m2ts": "video/mp2t"
        default: "application/octet-stream"
        }
    }
}
