import Foundation

/// One live channel from a playlist.
public struct Channel: Hashable, Sendable {
    public var name: String
    public var url: String
    public var tvgId: String?
    public var logo: String?
    public var group: String?
    public var headers: [String: String]

    public init(name: String, url: String, tvgId: String? = nil, logo: String? = nil, group: String? = nil, headers: [String: String] = [:]) {
        self.name = name
        self.url = url
        self.tvgId = tvgId
        self.logo = logo
        self.group = group
        self.headers = headers
    }

    /// A stable key for the channel, also when the playlist changes order.
    public var key: String { tvgId.flatMap(M3u.nonBlank) ?? url }

    /// The favourite key of each channel, by its link. A channel uses its guide ID when no other
    /// channel in the list has the same ID, because the ID stays when the link changes. Copies such
    /// as an HD and an SD channel with one ID use their links, so that each one is a favourite alone.
    public static func favoriteKeys(_ channels: [Channel]) -> [String: String] {
        var counts: [String: Int] = [:]
        for id in channels.compactMap({ $0.tvgId.flatMap(M3u.nonBlank) }) { counts[id, default: 0] += 1 }
        var keys: [String: String] = [:]
        for channel in channels {
            let id = channel.tvgId.flatMap(M3u.nonBlank)
            keys[channel.url] = id.flatMap { counts[$0, default: 0] > 1 ? nil : $0 } ?? channel.url
        }
        return keys
    }
}

public struct Playlist: Hashable, Sendable {
    public var channels: [Channel]
    public var guideUrls: [String]

    public init(channels: [Channel], guideUrls: [String]) {
        self.channels = channels
        self.guideUrls = guideUrls
    }
}

/// Reads an M3U playlist in the extended IPTV form.
public enum M3u {
    public static func parse(_ text: String) -> Playlist {
        var channels: [Channel] = []
        var guides: [String] = []
        var info: [String: String] = [:]
        var name: String?
        var headers: [String: String] = [:]

        let lines = text.split(omittingEmptySubsequences: true) { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasPrefix("#EXTM3U") {
                let attrs = attributes(line)
                if let list = attrs["x-tvg-url"] ?? attrs["url-tvg"] {
                    guides += list.split(separator: ",", omittingEmptySubsequences: false)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
            } else if line.hasPrefix("#EXTINF") {
                if let comma = nameComma(line) {
                    info = attributes(String(line[..<comma]))
                    let rest = line[line.index(after: comma)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    name = rest.isEmpty ? nil : rest
                } else {
                    info = attributes(line)
                    name = nil
                }
            } else if line.hasPrefix("#EXTVLCOPT:") {
                let option = line.dropFirst("#EXTVLCOPT:".count)
                let equals = option.firstIndex(of: "=")
                let key = option[..<(equals ?? option.endIndex)].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let value = equals.map { option[option.index(after: $0)...].trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
                switch key {
                case "http-user-agent": headers["User-Agent"] = value
                case "http-referrer", "http-referer": headers["Referer"] = value
                case "http-origin": headers["Origin"] = value
                default: break
                }
            } else if line.hasPrefix("#EXTHTTP:") {
                let json = Data(line.dropFirst("#EXTHTTP:".count).utf8)
                // A value that is not a text, a number, or a boolean is left out.
                for (key, value) in (try? JSONValue.parse(json))?.objectValue ?? [:] {
                    if let text = value.stringValue { headers[key] = text }
                }
            } else if line.hasPrefix("#") {
                continue
            } else {
                let (url, pipeHeaders) = splitPipeHeaders(line)
                channels.append(Channel(
                    name: name ?? info["tvg-name"] ?? url,
                    url: url,
                    tvgId: info["tvg-id"].flatMap(nonBlank),
                    logo: info["tvg-logo"].flatMap(nonBlank),
                    group: info["group-title"].flatMap(nonBlank),
                    headers: headers.merging(pipeHeaders) { _, pipe in pipe }
                ))
                info = [:]
                name = nil
                headers = [:]
            }
        }
        return Playlist(channels: channels, guideUrls: guides)
    }

    static func nonBlank(_ text: String) -> String? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    /// Reads each `name="value"` pair. The name holds ASCII letters, digits, `_`, and `-`.
    /// The names become lower case. When a name comes two times, the last value wins.
    private static func attributes(_ line: String) -> [String: String] {
        let scalars = Array(line.unicodeScalars)
        var result: [String: String] = [:]
        var i = 0
        while i < scalars.count {
            guard isNameScalar(scalars[i]) else { i += 1; continue }
            var end = i
            while end < scalars.count && isNameScalar(scalars[end]) { end += 1 }
            if end + 1 < scalars.count, scalars[end] == "=", scalars[end + 1] == "\"",
               let close = scalars[(end + 2)...].firstIndex(of: "\"") {
                let key = String(String.UnicodeScalarView(scalars[i..<end])).lowercased()
                result[key] = String(String.UnicodeScalarView(scalars[(end + 2)..<close]))
                i = close + 1
            } else {
                // No pair starts at any point of this name, because each one ends at the same place.
                i = end
            }
        }
        return result
    }

    private static func isNameScalar(_ s: Unicode.Scalar) -> Bool {
        s.isASCII && (s == "_" || s == "-" || CharacterSet.alphanumerics.contains(s))
    }

    /// Finds the comma before the name. A comma inside quotes does not count.
    private static func nameComma(_ line: String) -> String.Index? {
        var quoted = false
        for index in line.indices {
            if line[index] == "\"" { quoted.toggle() }
            else if line[index] == "," && !quoted { return index }
        }
        return nil
    }

    /// Reads the Kodi form `url|User-Agent=x&Referer=y`.
    private static func splitPipeHeaders(_ line: String) -> (String, [String: String]) {
        guard let pipe = line.firstIndex(of: "|") else { return (line, [:]) }
        var headers: [String: String] = [:]
        for pair in line[line.index(after: pipe)...].split(separator: "&", omittingEmptySubsequences: false) {
            guard let equals = pair.firstIndex(of: "=") else { continue }
            let key = pair[..<equals].trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty { continue }
            headers[key] = formDecode(pair[pair.index(after: equals)...])
        }
        return (String(line[..<pipe]), headers)
    }

    /// Decodes like `java.net.URLDecoder`: `+` is a space and `%XX` is a byte of UTF-8.
    /// A bad escape keeps the text as it is.
    private static func formDecode(_ text: Substring) -> String {
        let spaced = text.replacingOccurrences(of: "+", with: " ")
        return spaced.removingPercentEncoding ?? spaced
    }
}
