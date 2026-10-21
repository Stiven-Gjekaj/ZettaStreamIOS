import Foundation

/// An installed addon: its manifest and the URL that it answers on.
public struct Addon: Hashable, Sendable {
    public let manifestUrl: String
    public let manifest: Manifest
    public let baseUrl: String

    public init(manifestUrl: String, manifest: Manifest) {
        self.manifestUrl = manifestUrl
        self.manifest = manifest
        self.baseUrl = Addon.baseUrl(of: manifestUrl)
    }

    public var name: String { manifest.name }

    /// Tells if this addon gives `resource` for a title of `type` with `id`.
    public func supports(_ resource: String, type: String, id: String) -> Bool {
        guard let entry = manifest.resources.first(where: { $0.name == resource }) else { return false }
        let types = entry.types ?? manifest.types
        guard types.contains(type) else { return false }
        guard let prefixes = entry.idPrefixes ?? manifest.idPrefixes else { return true }
        return prefixes.contains { id.hasPrefix($0) }
    }

    /// Makes the URL of one request, in the form that the protocol defines.
    /// The extras keep the order of the list.
    public func resourceUrl(_ resource: String, type: String, id: String, extras: [(String, String)] = []) -> String {
        let extra = extras.isEmpty ? "" : "/" + extras.map { "\($0.0)=\(Addon.encodeComponent($0.1))" }.joined(separator: "&")
        return "\(baseUrl)/\(resource)/\(Addon.encodeComponent(type))/\(Addon.encodeComponent(id))\(extra).json"
    }

    /// Changes a `stremio://` link to HTTPS.
    public static func normalizeManifestUrl(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("stremio://") ? "https://" + trimmed.dropFirst("stremio://".count) : trimmed
    }

    /// Removes the query and `/manifest.json`.
    public static func baseUrl(of manifestUrl: String) -> String {
        var url = normalizeManifestUrl(manifestUrl)
        if let query = url.firstIndex(of: "?") { url = String(url[..<query]) }
        if url.hasSuffix("/manifest.json") { url.removeLast("/manifest.json".count) }
        while url.hasSuffix("/") { url.removeLast() }
        return url
    }

    private static let unreserved = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()".utf8)

    /// Encodes like `encodeURIComponent` in JavaScript, as Stremio does.
    public static func encodeComponent(_ value: String) -> String {
        var out = ""
        for byte in value.utf8 {
            if unreserved.contains(byte) { out.append(Character(UnicodeScalar(byte))) }
            else { out += String(format: "%%%02X", byte) }
        }
        return out
    }
}
