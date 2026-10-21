import Foundation

/// The kind of a stream link, which tells the player how to read it.
public enum MediaKind: String, Hashable, Sendable, Codable {
    case hls
    case dash
    case file

    private static let fileEndings = [".mp4", ".mkv", ".webm", ".avi", ".mov", ".ts", ".m4v", ".mp3", ".aac"]

    /// Finds the kind from the link. An HLS link from a proxy often ends in a
    /// name such as `/proxy/bound`, with the `.m3u8` address in a parameter.
    /// Nil when the link does not tell.
    public static func from(url: String) -> MediaKind? {
        // A form decode, as in the Android app: a plus is a space. A bad escape keeps the link as it is.
        let text = (url.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? url).lowercased()
        let path = String(text.prefix { $0 != "?" }.prefix { $0 != "#" })
        if path.hasSuffix(".m3u8") || path.hasSuffix(".m3u") { return .hls }
        if path.hasSuffix(".mpd") { return .dash }
        if fileEndings.contains(where: path.hasSuffix) { return .file }
        if text.contains(".m3u8") { return .hls }
        if text.contains(".mpd") || text.contains("format=mpd") { return .dash }
        return nil
    }

    /// Finds the kind from the answer of the server: its content type and its first bytes.
    public static func from(contentType: String?, start: Data) -> MediaKind? {
        let type = (contentType ?? "").lowercased()
        let head = String(String.UnicodeScalarView(String(decoding: start, as: UTF8.self).unicodeScalars
            .drop { ["\u{FEFF}", " ", "\r", "\n", "\t"].contains($0) }))
        if type.contains("mpegurl") || head.hasPrefix("#EXTM3U") { return .hls }
        if type.contains("dash+xml") || ((head.hasPrefix("<?xml") || head.hasPrefix("<MPD")) && head.contains("<MPD")) { return .dash }
        if type.hasPrefix("video/") || type.hasPrefix("audio/") || type.contains("octet-stream") { return .file }
        return nil
    }
}
