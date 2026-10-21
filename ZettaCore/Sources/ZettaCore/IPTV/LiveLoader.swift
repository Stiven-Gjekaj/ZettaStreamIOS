import Foundation

public struct LiveState: Hashable, Sendable {
    public var channels: [Channel]
    public var guide: Guide
    public var loading: Bool
    public var loaded: Bool
    /// The error text of each playlist or guide that did not load, by its URL.
    public var failures: [String: String]

    public init(channels: [Channel] = [], guide: Guide = .empty, loading: Bool = false, loaded: Bool = false, failures: [String: String] = [:]) {
        self.channels = channels
        self.guide = guide
        self.loading = loading
        self.loaded = loaded
        self.failures = failures
    }
}

/// Loads the IPTV playlists and the TV guides in the source list.
public struct LiveLoader: Sendable {
    private static let hour: Int64 = 3_600_000
    private let client: FileClient

    public init(client: FileClient = FileClient()) {
        self.client = client
    }

    /// Loads all playlists at the same time, then all guides. A source that fails does not
    /// stop the others. `onChannels` gets the channels before the guides load, so that the
    /// screen can show them early. `now` is in milliseconds since 1970.
    public func load(_ sources: [Source], now: Int64, onChannels: @Sendable ([Channel]) async -> Void = { _ in }) async -> LiveState {
        var failures: [String: String] = [:]
        let playlistUrls = sources.filter { $0.kind == .playlist }.map(\.url)
        let playlists = await inOrder(playlistUrls) { url in
            M3u.parse(String(decoding: try await client.data(url), as: UTF8.self))
        }
        var loaded: [Playlist] = []
        for (url, result) in zip(playlistUrls, playlists) {
            switch result {
            case .success(let playlist): loaded.append(playlist)
            case .failure(let error): failures[url] = Self.message(error)
            }
        }
        var seen = Set<String>()
        let channels = loaded.flatMap(\.channels).filter { seen.insert($0.url).inserted }
        await onChannels(channels)

        // Only the guides of the channels in the playlists are kept, because a guide can be very large.
        let ids = Set(channels.compactMap(\.tvgId))
        var seenGuides = Set<String>()
        let guideUrls = (sources.filter { $0.kind == .guide }.map(\.url) + loaded.flatMap(\.guideUrls))
            .filter { seenGuides.insert($0).inserted }
        var guide = Guide.empty
        if !ids.isEmpty {
            let from = now - 3 * Self.hour, to = now + 24 * Self.hour
            let guides = await inOrder(guideUrls) { url in
                try Xmltv.parse(try await client.data(url), channelIds: ids, from: from, to: to)
            }
            for (url, result) in zip(guideUrls, guides) {
                switch result {
                case .success(let one): guide = guide + one
                case .failure(let error): failures[url] = Self.message(error)
                }
            }
        }
        return LiveState(channels: channels, guide: guide, loading: false, loaded: true, failures: failures)
    }

    /// Runs `work` for each URL at the same time and gives the results in the order of the URLs.
    private func inOrder<T: Sendable>(_ urls: [String], _ work: @escaping @Sendable (String) async throws -> T) async -> [Result<T, any Error>] {
        await withTaskGroup(of: (Int, Result<T, any Error>).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    // The index goes into a constant before the first await. See AddonRepository.install.
                    let position = index
                    let result: Result<T, any Error>
                    do { result = .success(try await work(url)) } catch { result = .failure(error) }
                    return (position, result)
                }
            }
            var results = [Result<T, any Error>?](repeating: nil, count: urls.count)
            for await (index, result) in group { results[index] = result }
            return results.compactMap { $0 }
        }
    }

    private static func message(_ error: any Error) -> String {
        if let http = error as? HTTPError { return "HTTP \(http.status)" }
        let text = error.localizedDescription
        return text.isEmpty ? "error" : text
    }
}
