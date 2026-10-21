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

    /// The numbers from `low` to `high`. Empty when `high` is less than `low`.
    private static func span(_ low: Int, _ high: Int) -> [Int] {
        high < low ? [] : Array(low...high)
    }

    /// Selects the pieces to download: the head and the tail of the file,
    /// which a player reads first, and a window ahead of the read position.
    /// The engine downloads nothing else, so it does not take the whole file.
    public static func wanted(firstPiece: Int, lastPiece: Int, readPiece: Int, aheadPieces: Int, edgePieces: Int) -> Set<Int> {
        if lastPiece < firstPiece { return [] }
        let head = span(firstPiece, min(lastPiece, firstPiece + edgePieces - 1))
        let tail = span(max(firstPiece, lastPiece - edgePieces + 1), lastPiece)
        let start = min(max(readPiece, firstPiece), lastPiece)
        let window = span(start, min(lastPiece, start + aheadPieces))
        return Set(head + tail + window)
    }

    /// A piece that the player needs now.
    public static let priorityNow = 7
    /// A piece that the player needs later. It downloads only with spare speed.
    public static let priorityLater = 1

    /// Gives a priority to each piece of the torrent. The pieces right after
    /// `readPiece` are needed now. The rest of the window ahead, and the head and
    /// the tail of the file, download only with spare speed. All other pieces do
    /// not download. With one priority for all wanted pieces, the next piece
    /// shares the speed with a hundred others and comes late.
    public static func priorities(numPieces: Int, firstPiece: Int, lastPiece: Int, readPiece: Int,
                                  nowPieces: Int, aheadPieces: Int, edgePieces: Int) -> [Int] {
        var out = [Int](repeating: 0, count: max(0, numPieces))
        for p in wanted(firstPiece: firstPiece, lastPiece: lastPiece, readPiece: readPiece, aheadPieces: aheadPieces, edgePieces: edgePieces)
        where out.indices.contains(p) {
            out[p] = priorityLater
        }
        guard lastPiece >= firstPiece else { return out }
        let start = min(max(readPiece, firstPiece), lastPiece)
        for p in span(start, min(lastPiece + 1, start + nowPieces) - 1) where out.indices.contains(p) {
            out[p] = priorityNow
        }
        return out
    }

    private static let mib: Int64 = 1024 * 1024

    /// The bytes that the player needs now, after the read position.
    public static let nowBytes: Int64 = 4 * mib

    /// The bytes to download ahead of the play position: about 1/30 of the file,
    /// which is about three minutes of a film, from 24 MB to 96 MB. A fixed large
    /// window downloads much that a viewer who stops early never needs.
    public static func windowBytes(fileSize: Int64) -> Int64 {
        min(max(fileSize / 30, 24 * mib), 96 * mib)
    }

    /// The number of pieces in `bytes`, at least one.
    public static func piecesFor(bytes: Int64, pieceLength: Int) -> Int {
        max(1, Int((bytes + Int64(pieceLength) - 1) / Int64(pieceLength)))
    }

    /// Reads an HTTP `Range` header such as `bytes=100-` or `bytes=100-199`.
    /// Gives the whole file when there is no header, and nil when the range
    /// is outside the file. The end of the result is not in the range.
    public static func range(header: String?, size: Int64) -> Range<Int64>? {
        if size <= 0 { return nil }
        guard let header, header.hasPrefix("bytes=") else { return 0..<size }
        let spec = String(header.dropFirst("bytes=".count).prefix { $0 != "," }).trimmingCharacters(in: .whitespacesAndNewlines)
        let dash = spec.firstIndex(of: "-")
        let start = String(spec[..<(dash ?? spec.endIndex)]).trimmingCharacters(in: .whitespacesAndNewlines)
        let end = dash.map { String(spec[spec.index(after: $0)...]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        if start.isEmpty && !end.isEmpty {
            // A suffix range: the last N bytes.
            guard let n = Int64(end) else { return nil }
            return min(max(size - n, 0), size)..<size
        }
        guard let s = Int64(start) else { return nil }
        let e = Int64(end).map { min($0, size - 1) } ?? (size - 1)
        if s >= size || s > e { return nil }
        return s..<(e + 1)
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
