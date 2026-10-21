import Foundation

public struct HTTPError: Error, Equatable, CustomStringConvertible {
    public let status: Int
    public let url: String
    public var description: String { "HTTP \(status) from \(url)" }
}

/// Sends the requests of the Stremio addon protocol.
public struct AddonClient: Sendable {
    private let session: URLSession
    private let userAgent: String

    public init(session: URLSession = .shared, userAgent: String = ZettaCore.appName) {
        self.session = session
        self.userAgent = userAgent
    }

    public func install(_ manifestUrl: String) async throws -> Addon {
        let url = Addon.normalizeManifestUrl(manifestUrl)
        let root = try await get(url)
        guard root.objectValue != nil else { throw ManifestError(message: "The manifest is not a JSON object") }
        return Addon(manifestUrl: url, manifest: try Manifest.parse(root))
    }

    public func catalog(_ addon: Addon, _ catalog: Catalog, extras: [(String, String)] = []) async throws -> [MetaPreview] {
        let root = try await get(addon.resourceUrl("catalog", type: catalog.type, id: catalog.id, extras: extras))
        return (root["metas"]?.arrayValue ?? [])
            .compactMap(MetaPreview.init(json:))
            .filter { !$0.id.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(Display.preview)
    }

    public func meta(_ addon: Addon, type: String, id: String) async throws -> Meta? {
        let root = try await get(addon.resourceUrl("meta", type: type, id: id))
        return root["meta"].flatMap(Meta.init(json:)).map(Display.meta)
    }

    public func streams(_ addon: Addon, type: String, videoId: String) async throws -> [AddonStream] {
        let root = try await get(addon.resourceUrl("stream", type: type, id: videoId))
        return (root["streams"]?.arrayValue ?? []).map(AddonStream.init(json:))
    }

    public func subtitles(_ addon: Addon, type: String, videoId: String) async throws -> [Subtitle] {
        let root = try await get(addon.resourceUrl("subtitles", type: type, id: videoId))
        return (root["subtitles"]?.arrayValue ?? []).compactMap(Subtitle.init(json:))
    }

    /// Gets `url` and reads the JSON. When the task stops, the request stops too.
    private func get(_ url: String) async throws -> JSONValue {
        guard let address = URL(string: url) else { throw URLError(.badURL) }
        var request = URLRequest(url: address, timeoutInterval: 30)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HTTPError(status: http.statusCode, url: url)
        }
        return try JSONValue.parse(data)
    }
}
