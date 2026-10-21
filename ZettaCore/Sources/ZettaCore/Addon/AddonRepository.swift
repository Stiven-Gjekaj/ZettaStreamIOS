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

    /// A text that tells why a request failed.
    static func message(_ error: Error) -> String {
        switch error {
        case let e as HTTPError: return e.description
        case let e as ManifestError: return e.message
        default: return error.localizedDescription
        }
    }
}
