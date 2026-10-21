import Foundation
import SwiftUI
import ZettaCore

/// The state of the interface, and the actions that change the data of the user.
@MainActor
final class AppModel: ObservableObject {
    let container: AppContainer

    @Published private(set) var profiles: ProfilesData
    /// False until the viewer chooses on "Who is watching?". The app starts there.
    @Published var profileChosen = false
    @Published private(set) var library: LibraryData
    @Published private(set) var settings: ViewerSettings
    @Published private(set) var sources: [Source]
    @Published private(set) var addonState = AddonState(loading: true)
    @Published private(set) var live = LiveState()
    @Published private(set) var latestRelease: Release?
    @Published var tab: Tab = .home
    @Published var paths: [Tab: NavigationPath] = [:]
    @Published var playback: Playback?
    @Published var toast: String?
    @Published var homeFilter: String?

    private var tasks: [Task<Void, Never>] = []
    private var liveTask: Task<Void, Never>?

    init(container: AppContainer = AppContainer()) {
        self.container = container
        profiles = container.profiles.profiles
        library = container.library.data
        settings = container.settings.settings
        sources = container.sources.sources
        observe()
        Task { await container.addons.install(sources) }
        Task { latestRelease = await container.updates.update(from: AppInfo.version) }
    }

    private func observe() {
        let c = container
        tasks.append(Task { [weak self] in
            for await value in c.profiles.updates() { self?.profiles = value }
        })
        tasks.append(Task { [weak self] in
            for await value in c.library.updates() { self?.library = value }
        })
        tasks.append(Task { [weak self] in
            for await value in c.settings.updates() { self?.settings = value }
        })
        tasks.append(Task { [weak self] in
            for await value in await c.addons.states() { self?.addonState = value }
        })
    }

    var currentProfile: Profile? {
        profiles.profiles.first { $0.id == profiles.last } ?? profiles.profiles.first
    }

    // MARK: Navigation

    func path(_ tab: Tab) -> Binding<NavigationPath> {
        Binding(get: { self.paths[tab] ?? NavigationPath() }, set: { self.paths[tab] = $0 })
    }

    func open(_ route: Route) {
        paths[tab, default: NavigationPath()].append(route)
    }

    func back() {
        guard var path = paths[tab], !path.isEmpty else { return }
        path.removeLast()
        paths[tab] = path
    }

    func play(_ playback: Playback) {
        self.playback = playback
    }

    func show(_ message: String) {
        toast = message
    }

    // MARK: Profiles

    func selectProfile(_ id: String) {
        do {
            try container.selectProfile(id)
            library = container.library.data
            settings = container.settings.settings
            paths = [:]
            tab = .home
            profileChosen = true
        } catch {
            show("The profile did not open: \(error.localizedDescription)")
        }
    }

    // MARK: Sources

    /// Replaces the full source list, and loads the new addons and playlists.
    @discardableResult
    func saveSources(_ text: String) -> [Source] {
        do {
            let saved = try container.sources.replace(text)
            sources = saved
            Task { await container.addons.install(saved) }
            reloadLive()
            return saved
        } catch {
            show("The list was not saved: \(error.localizedDescription)")
            return sources
        }
    }

    // MARK: Library

    func toggleWatchlist(_ meta: MetaPreview) {
        let adding = !container.library.isInWatchlist(meta.id)
        try? container.library.toggleWatchlist(meta)
        show(adding ? "Added to the watchlist: \(meta.name)" : "Removed from the watchlist: \(meta.name)")
    }

    func toggleWatched(_ id: String) {
        try? container.library.toggleWatched(id)
    }

    func markWatched(_ id: String) {
        try? container.library.markWatched(id)
    }

    func saveProgress(videoId: String, meta: MetaPreview, label: String, position: Int, duration: Int) {
        try? container.library.saveProgress(videoId: videoId, meta: meta, label: label, position: position, duration: duration)
    }

    func toggleFavoriteChannel(_ key: String) {
        _ = try? container.library.toggleFavoriteChannel(key)
    }

    // MARK: Settings

    func updateSettings(_ change: (inout ViewerSettings) -> Void) {
        try? container.settings.update(change)
    }

    // MARK: Live TV

    /// Loads the channels and the guides one time. A new source list loads them again.
    func loadLiveIfNeeded() {
        guard !live.loaded, !live.loading else { return }
        reloadLive()
    }

    func reloadLive() {
        liveTask?.cancel()
        let sources = self.sources
        guard sources.contains(where: { $0.kind != .addon }) else {
            live = LiveState(loaded: true)
            return
        }
        live.loading = true
        let loader = container.live
        liveTask = Task { [weak self] in
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let state = await loader.load(sources, now: now) { channels in
                await MainActor.run { self?.live.channels = channels }
            }
            guard !Task.isCancelled else { return }
            self?.live = state
        }
    }

    /// Cycles the type filter of the home screen.
    func cycleFilter() async {
        let options: [String?] = [nil] + (await container.addons.types())
        let index = options.firstIndex(of: homeFilter) ?? 0
        homeFilter = options[(index + 1) % options.count]
        show("Filter: \(Display.typeLabel(homeFilter))")
    }
}
