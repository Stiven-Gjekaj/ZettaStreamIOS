import Foundation

/// The installed addons, and the sources that gave no addon.
public struct AddonState: Hashable, Sendable {
    public var addons: [Addon] = []
    /// The reason of each failure, by the URL of the source.
    public var failures: [String: String] = [:]
    public var loading = false

    public init(addons: [Addon] = [], failures: [String: String] = [:], loading: Bool = false) {
        self.addons = addons
        self.failures = failures
        self.loading = loading
    }
}

/// The streams of one addon, or the reason that it gave none.
public struct StreamGroup: Hashable, Sendable {
    public let addon: Addon
    public var streams: [AddonStream]
    /// Torrent streams that the app hides because the viewer turned torrents off.
    public var hiddenTorrents: Int
    /// Links that no part of the app can play, such as a YouTube ID or a link to another app.
    public var unplayable: Int
    public var error: String?

    public init(addon: Addon, streams: [AddonStream] = [], hiddenTorrents: Int = 0, unplayable: Int = 0, error: String? = nil) {
        self.addon = addon
        self.streams = streams
        self.hiddenTorrents = hiddenTorrents
        self.unplayable = unplayable
        self.error = error
    }
}

/// Installs the addons in the source list and sends requests to all of them.
/// All addons get each request at the same time.
public actor AddonRepository {
    /// The official OpenSubtitles addon of Stremio.
    public static let openSubtitles = "https://opensubtitles-v3.strem.io/manifest.json"

    private let client: AddonClient
    private let fallbackSubtitlesUrl: String?
    private let clock: @Sendable () -> Date
    private let subtitleWait: Duration

    public private(set) var state = AddonState(loading: true)
    private var watchers: [UUID: AsyncStream<AddonState>.Continuation] = [:]
    private var sources: [Source] = []
    /// Goes up with each install. An install that a newer one replaced does not set the state.
    private var generation = 0
    private var streamCache: [String: (Date, [StreamGroup])] = [:]
    private var catalogCache: [String: [MetaPreview]] = [:]
    private var searchCache: [String: (Date, [MetaPreview])] = [:]

    /// How long the app keeps the results of a search: 10 minutes.
    public static let searchKeep: TimeInterval = 10 * 60

    /// The time between two updates of the search results while addons answer.
    static let searchUpdate: Duration = .milliseconds(300)

    /// How long a list of streams stays in memory: 15 minutes.
    public static let streamKeep: TimeInterval = 15 * 60

    /// - Parameters:
    ///   - fallbackSubtitlesUrl: The addon that gives subtitles when no installed addon does.
    ///   - clock: The time for the caches. A test sets its own time.
    ///   - subtitleWait: The time that each subtitle addon gets.
    public init(
        client: AddonClient,
        fallbackSubtitlesUrl: String? = AddonRepository.openSubtitles,
        clock: @escaping @Sendable () -> Date = { Date() },
        subtitleWait: Duration = .seconds(4)
    ) {
        self.client = client
        self.fallbackSubtitlesUrl = fallbackSubtitlesUrl
        self.clock = clock
        self.subtitleWait = subtitleWait
    }

    /// Gives the state now, and then each change of it.
    public func states() -> AsyncStream<AddonState> {
        let (stream, continuation) = AsyncStream.makeStream(of: AddonState.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        watchers[id] = continuation
        continuation.yield(state)
        continuation.onTermination = { _ in Task { await self.forget(id) } }
        return stream
    }

    private func forget(_ id: UUID) {
        watchers[id] = nil
    }

    private func set(_ new: AddonState) {
        state = new
        for watcher in watchers.values { watcher.yield(new) }
    }

    /// Installs the addons of `sources`. The other kinds of source are left out.
    /// Call it each time that the source list changes. When a newer list comes
    /// before this install ends, only the newer list sets the state.
    public func install(_ sources: [Source]) async {
        self.sources = sources
        generation += 1
        let mine = generation
        var loading = state
        loading.loading = true
        set(loading)
        let urls = sources.filter { $0.kind == .addon }.map(\.url)
        let client = client
        let results = await withTaskGroup(of: (Int, Result<Addon, Error>).self) { group in
            for (i, url) in urls.enumerated() {
                group.addTask {
                    do { return (i, .success(try await client.install(url))) } catch { return (i, .failure(error)) }
                }
            }
            var all = [Result<Addon, Error>?](repeating: nil, count: urls.count)
            for await (i, result) in group { all[i] = result }
            return all.compactMap { $0 }
        }
        guard mine == generation else { return }
        var next = AddonState()
        for (url, result) in zip(urls, results) {
            switch result {
            case .success(let addon): next.addons.append(addon)
            case .failure(let error): next.failures[url] = Self.message(error)
            }
        }
        set(next)
    }

    /// Installs each addon again, for example after the network comes back.
    public func retry() async {
        await install(sources)
    }

    /// Every row that the addons can give, in the order of `HomeRows.order`.
    public func homeRows() -> [CatalogRow] {
        HomeRows.order(state.addons.flatMap(HomeRows.of))
    }

    /// The home rows in the order that the viewer chose.
    public func homeRows(order: [String]) -> [CatalogRow] {
        HomeRows.arrange(homeRows(), keys: order)
    }

    /// The types that the home screen can filter by, in a fixed order. Each kind shows one time.
    public func types() -> [String] {
        let order = ["movie", "series", "anime", "tv", "sport"]
        var keys: [String] = []
        for row in homeRows() {
            let key = Display.typeKey(row.catalog.type)
            if !keys.contains(key) { keys.append(key) }
        }
        return keys.enumerated()
            .sorted { (order.firstIndex(of: $0.element) ?? 99, $0.offset) < (order.firstIndex(of: $1.element) ?? 99, $1.offset) }
            .map(\.element)
    }

    /// The last answer of a catalog, so that a screen comes back at once after Back.
    public func cachedCatalog(_ row: CatalogRow) -> [MetaPreview]? {
        catalogCache[row.key]
    }

    public func catalog(_ row: CatalogRow) async throws -> [MetaPreview] {
        let metas = try await client.catalog(row.addon, row.catalog, extras: row.extras)
        catalogCache[row.key] = metas
        return metas
    }

    /// Searches each catalog that supports a search. Results come as they arrive, as one list
    /// where each title shows one time and the best match comes first. The last list holds
    /// all answers. The same search within `searchKeep` answers from memory.
    public func search(_ query: String) -> AsyncStream<[MetaPreview]> {
        let key = SearchRank.normalize(query)
        if let (time, all) = searchCache[key], clock().timeIntervalSince(time) < Self.searchKeep {
            return AsyncStream { continuation in
                continuation.yield(all)
                continuation.finish()
            }
        }
        let catalogs = state.addons.flatMap { a in a.manifest.catalogs.filter(\.supportsSearch).map { (a, $0) } }
        let client = client
        return AsyncStream { continuation in
            // The task does not run on this actor, so a merge never holds back the other requests.
            let task = Task.detached {
                // One answer for each catalog, in the order of the source list, so the order does not depend on speed.
                let answers = Answers(count: catalogs.count)
                // A change that comes while an update waits joins the next update.
                let (changes, changed) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
                let updates = Task {
                    for await _ in changes {
                        continuation.yield(SearchRank.merge(query: query, answers: answers.all))
                        try? await Task.sleep(for: Self.searchUpdate)
                        if Task.isCancelled { break }
                    }
                }
                await withTaskGroup(of: Void.self) { group in
                    for (i, (addon, catalog)) in catalogs.enumerated() {
                        group.addTask {
                            let metas = (try? await client.catalog(addon, catalog, extras: [("search", query)])) ?? []
                            answers.set(i, metas)
                            changed.yield()
                        }
                    }
                }
                updates.cancel()
                changed.finish()
                await updates.value
                let all = SearchRank.merge(query: query, answers: answers.all)
                if !catalogs.isEmpty && !Task.isCancelled { await self.keepSearch(key, all) }
                continuation.yield(all)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func keepSearch(_ key: String, _ all: [MetaPreview]) {
        searchCache[key] = (clock(), all)
    }

    /// The answers of a search, which the requests write at the same time.
    private final class Answers: @unchecked Sendable {
        private let lock = NSLock()
        private var lists: [[MetaPreview]?]

        init(count: Int) { lists = Array(repeating: nil, count: count) }

        func set(_ index: Int, _ metas: [MetaPreview]) { lock.withLock { lists[index] = metas } }

        var all: [[MetaPreview]] { lock.withLock { lists.compactMap { $0 } } }
    }

    /// Gets the full details from the first addon that has them.
    /// With no answer, the details are the facts of the card.
    public func meta(_ preview: MetaPreview) async -> Meta {
        for addon in state.addons where addon.supports("meta", type: preview.type, id: preview.id) {
            let meta = try? await client.meta(addon, type: preview.type, id: preview.id)
            // A series with only a placeholder episode tells nothing. The next addon can have the real list.
            if let meta, !Display.isPlaceholder(meta) { return meta }
        }
        var card = MetaPreview(id: preview.id, type: preview.type, name: preview.name)
        card.poster = preview.poster
        card.background = preview.background
        card.logo = preview.logo
        card.description = preview.description
        card.releaseInfo = preview.releaseInfo
        card.imdbRating = preview.imdbRating
        card.genres = preview.genres
        return Meta(preview: card)
    }

    /// The last full list of streams for a video, so that Back from the player shows
    /// the same list at once. A stream link can expire, so the list is kept for
    /// `streamKeep` only.
    public func cachedStreams(type: String, videoId: String, withTorrents: Bool) -> [StreamGroup]? {
        guard let (time, groups) = streamCache["\(type)|\(videoId)|\(withTorrents)"],
              clock().timeIntervalSince(time) < Self.streamKeep else { return nil }
        return groups
    }

    public func keepStreams(type: String, videoId: String, withTorrents: Bool, groups: [StreamGroup]) {
        streamCache["\(type)|\(videoId)|\(withTorrents)"] = (clock(), groups)
    }

    /// Asks each addon for streams. Each group comes when its addon answers, and the
    /// stream ends after the last addon. Torrent streams come too when `withTorrents` is true.
    public func streams(type: String, videoId: String, withTorrents: Bool = false) -> AsyncStream<StreamGroup> {
        let addons = state.addons.filter { $0.supports("stream", type: type, id: videoId) }
        let client = client
        return AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for addon in addons {
                        group.addTask {
                            let found: StreamGroup
                            do {
                                let all = try await client.streams(addon, type: type, videoId: videoId)
                                let playable = all.filter { $0.isPlayable(withTorrents: withTorrents) }
                                let hidden = withTorrents ? 0 : all.filter(\.isTorrent).count
                                found = StreamGroup(addon: addon, streams: playable, hiddenTorrents: hidden,
                                                    unplayable: all.count - playable.count - hidden)
                            } catch {
                                found = StreamGroup(addon: addon, error: Self.message(error))
                            }
                            continuation.yield(found)
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Asks one addon for the playable streams of a video. Nil when the addon is not installed.
    public func streamsFrom(addonUrl: String, type: String, videoId: String, withTorrents: Bool = false) async -> [AddonStream]? {
        guard let addon = state.addons.first(where: { $0.manifestUrl == addonUrl }) else { return nil }
        let all = (try? await client.streams(addon, type: type, videoId: videoId)) ?? []
        return all.filter { $0.isPlayable(withTorrents: withTorrents) }
    }

    /// Asks each subtitle addon. When no installed addon gives subtitles for
    /// this video, the app asks OpenSubtitles, which is free and needs no key.
    /// Each addon gets `subtitleWait`. A slow addon does not hold back the
    /// subtitles of the others.
    ///
    /// An addon that does not know the ID, such as a Kitsu ID, can know its IMDb
    /// form. Give that form as `alias`.
    public func subtitles(type: String, videoId: String, alias: (type: String, id: String)? = nil) async -> [Subtitle] {
        let ids = [(type, videoId)] + (alias.map { [($0.type, $0.id)] } ?? [])
        func asked(_ addons: [Addon]) -> [(Addon, (String, String))] {
            addons.compactMap { addon in ids.first { addon.supports("subtitles", type: $0.0, id: $0.1) }.map { (addon, $0) } }
        }
        var requests = asked(state.addons)
        if requests.isEmpty, let fallback = await fallbackAddon() { requests = asked([fallback]) }
        let client = client
        let wait = subtitleWait
        let answers = await withTaskGroup(of: (Int, [Subtitle]).self) { group in
            for (i, (addon, id)) in requests.enumerated() {
                group.addTask {
                    let found = await Self.withTimeLimit(wait) { try? await client.subtitles(addon, type: id.0, videoId: id.1) }
                    return (i, found ?? [])
                }
            }
            var all = [[Subtitle]](repeating: [], count: requests.count)
            for await (i, found) in group { all[i] = found }
            return all
        }
        var seen = Set<String>()
        return answers.joined().filter { seen.insert($0.url).inserted }
    }

    private var fallback: Addon?

    private func fallbackAddon() async -> Addon? {
        guard let url = fallbackSubtitlesUrl else { return nil }
        if let fallback { return fallback }
        let installed = try? await client.install(url)
        if fallback == nil { fallback = installed }
        return fallback ?? installed
    }

    /// Gives the result of `work`, or nil when `limit` ends first. The work then stops.
    static func withTimeLimit<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(for: limit)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// A text that tells why a request failed.
    static func message(_ error: Error) -> String {
        switch error {
        case let e as HTTPError: return e.description
        case let e as ManifestError: return e.message
        default: return error.localizedDescription
        }
    }
}
