import Foundation

/// The kinds of source that one line can hold.
public enum SourceKind: String, Sendable, Codable {
    case addon, playlist, guide
}

public struct Source: Hashable, Sendable, Codable {
    public let url: String
    public let kind: SourceKind

    public init(url: String, kind: SourceKind) {
        self.url = url
        self.kind = kind
    }
}

/// Reads the text that the user pastes. One line holds one URL.
public enum SourceList {
    public static func parse(_ text: String) -> [Source] {
        var seen = Set<String>()
        var sources: [Source] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("stremio://") { line = "https://" + line.dropFirst("stremio://".count) }
            guard line.hasPrefix("http://") || line.hasPrefix("https://") else { continue }
            guard seen.insert(line).inserted else { continue }
            sources.append(Source(url: line, kind: kind(of: line)))
        }
        return sources
    }

    public static func format(_ sources: [Source]) -> String {
        sources.map(\.url).joined(separator: "\n")
    }

    private static func kind(of url: String) -> SourceKind {
        let path = url.split(separator: "?", maxSplits: 1).first.map(String.init) ?? url
        let bare = (path.split(separator: "#", maxSplits: 1).first.map(String.init) ?? path).lowercased()
        if bare.hasSuffix("/manifest.json") { return .addon }
        if bare.hasSuffix(".xml") || bare.hasSuffix(".xml.gz") || bare.contains("epg") { return .guide }
        return .playlist
    }
}
