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

    /// The number of bytes that `detect` reads from the server.
    static let probeBytes = 1024

    /// Finds the kind from the link, or else asks the server for the first bytes.
    /// When neither tells, the player reads the link as a file.
    public static func detect(session: URLSession = .shared, url: String, headers: [String: String] = [:]) async -> MediaKind {
        if let kind = from(url: url) { return kind }
        return await probe(session: session, url: url, headers: headers) ?? .file
    }

    private static func probe(session: URLSession, url: String, headers: [String: String]) async -> MediaKind? {
        guard let link = URL(string: url) else { return nil }
        var request = URLRequest(url: link)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.setValue("bytes=0-\(probeBytes - 1)", forHTTPHeaderField: "Range")
        do {
            let (bytes, response) = try await session.bytes(for: request)
            // A server can send the full file. Read only the start, then stop the download.
            defer { bytes.task.cancel() }
            var start = Data()
            for try await byte in bytes {
                start.append(byte)
                if start.count >= probeBytes { break }
            }
            let type = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")
            return from(contentType: type, start: start)
        } catch {
            return nil
        }
    }
}
