import SwiftUI
import ZettaCore

/// The first tab: the banner, the filter chips, the rows of the library, and the rows of the addons.
struct HomeScreen: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var model = HomeViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var vpnNotice = false

    /// The longest wait for the art of the banner before Home shows.
    private static let coverWait: UInt64 = 6_000_000_000

    var body: some View {
        let shown = app.shownHomeRows(model.rows)
        let featured = model.featured(shown.first)
        GeometryReader { geo in
            ZStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if featured.isEmpty {
                            wordmark.padding(.top, geo.safeAreaInsets.top)
                        } else {
                            HomeHero(items: featured, topInset: geo.safeAreaInsets.top) { model.coverReady = true }
                        }
                        notices
                        library
                        if app.addonState.loading && model.rows.isEmpty && !app.sources.isEmpty {
                            HomePlaceholderRow()
                        }
                        ForEach(Array(shown.enumerated()), id: \.element.key) { index, row in
                            HomeCatalogRowView(
                                row: row,
                                metas: model.catalogs[row.key],
                                above: shown.prefix(index).compactMap { model.catalogs[$0.key]?.map(\.id) },
                                model: model)
                        }
                    }
                    .padding(.bottom, 48)
                }
                .ignoresSafeArea(.container, edges: .top)
                .opacity(model.isReady(app: app, shown: shown) ? 1 : 0)
                if !model.isReady(app: app, shown: shown) {
                    ProgressView().tint(Palette.accent)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: HomeTrigger(addons: app.addonState, order: app.settings.rowOrder)) {
            await model.refresh(app: app)
        }
        .task {
            try? await Task.sleep(nanoseconds: Self.coverWait)
            model.coverReady = true
        }
        .task(id: HomeEpisodesTrigger(shows: NewEpisodes.followed(app.library).map(\.id), watched: app.library.watched,
                                      loading: app.addonState.loading)) {
            await model.loadNewEpisodes(app: app)
        }
        .onAppear {
            if !HomeVpnNotice.shown && app.settings.vpnNotice {
                HomeVpnNotice.shown = true
                vpnNotice = true
            }
        }
        .alert("Use a VPN", isPresented: $vpnNotice) {
            Button("OK", role: .cancel) {}
            Button("Do not show again") { app.homeHideVpnNotice() }
        } message: {
            Text("Torrent streams connect your device to other people. They can see your IP address, "
                + "and in many countries a copyright holder can act against it. Use a VPN that permits P2P. "
                + "ZettaStream does not check this. You can turn off torrent streams, or this notice, in Settings.")
        }
    }

    /// The name of the app, when the banner has no titles.
    private var wordmark: some View {
        HStack(spacing: 0) {
            Text("Zetta").foregroundStyle(Palette.accent)
            Text("Stream").foregroundStyle(Palette.textSecondary)
        }
        .font(Karla.font(24, .bold, relativeTo: .title2))
        .padding(.horizontal, HomeSizes.gutter(sizeClass))
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }

    /// The update notice, the filter chips, and the messages for no sources and no addons.
    @ViewBuilder
    private var notices: some View {
        if let release = app.latestRelease {
            HomeUpdateNotice(release: release)
        }
        if model.types.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach([nil] + model.types.map(Optional.some), id: \.self) { type in
                        HomeChip(text: Display.typeLabel(type), selected: app.homeFilter == type) { app.homeFilter = type }
                    }
                }
                .padding(.horizontal, HomeSizes.gutter(sizeClass))
                .padding(.vertical, 8)
            }
        }
        if app.sources.isEmpty {
            HomeMessage(
                title: "No sources yet",
                text: "ZettaStream comes with no sources. Add your Stremio addons and IPTV playlists in Settings, Sources.")
            Button("Add sources") { app.open(.sources) }
                .buttonStyle(.zPrimary)
                .padding(.horizontal, HomeSizes.gutter(sizeClass))
        } else if !app.addonState.loading && model.rows.isEmpty && app.addonState.addons.isEmpty {
            HomeMessage(title: "No addon answered", text: "Check the network, or check the list in Settings, Sources.")
            Button("Try again") { app.homeRetryAddons() }
                .buttonStyle(.zPrimary)
                .padding(.horizontal, HomeSizes.gutter(sizeClass))
        }
    }

    /// Continue watching, New episodes, and the watchlist.
    @ViewBuilder
    private var library: some View {
        let width = HomeSizes.posterWidth(sizeClass)
        let resume = Library.continueWatching(app.library)
        if !resume.isEmpty && app.homeFilter == nil {
            HomeSectionTitle(text: "Continue watching")
            HomeCardRow {
                ForEach(resume, id: \.videoId) { progress in
                    Button { app.homeResume(progress) } label: {
                        HomePosterCard(
                            meta: progress.meta, width: width,
                            progress: progress.duration > 0 ? Double(progress.position) / Double(progress.duration) : nil,
                            caption: progress.label)
                    }
                    .buttonStyle(HomeCardButtonStyle())
                    .homeCardMenu(progress.meta, videoId: progress.videoId, details: true)
                }
            }
        }
        let fresh = model.newEpisodes.filter { app.passesHomeFilter($0.meta.preview.type) }
        if !fresh.isEmpty {
            let followed = NewEpisodes.followed(app.library)
            HomeSectionTitle(text: "New episodes", detail: "This week, from the shows that you follow")
            HomeCardRow {
                ForEach(fresh, id: \.video.id) { new in
                    // The card of the show in the watchlist or the history, so that its picture is the same.
                    let preview = followed.first { $0.id == new.meta.id } ?? new.meta.preview
                    Button { app.open(.detail(preview)) } label: {
                        HomePosterCard(meta: preview, width: width, caption: HomeNewEpisodeText.caption(new), badge: "NEW")
                    }
                    .buttonStyle(HomeCardButtonStyle())
                    .homeCardMenu(preview, videoId: new.video.id)
                }
            }
        }
        // The watchlist has its own row under Continue watching. The type filter applies to it too.
        let watchlist = app.library.watchlist.filter { app.passesHomeFilter($0.type) }
        if !watchlist.isEmpty {
            HomeSectionTitle(text: "Your watchlist", detail: Display.count(watchlist.count, "title"))
            HomePosterRow(metas: watchlist)
        }
    }
}

/// One row of an addon catalog. A row with no titles, or a row that mostly repeats a row above, does not show.
private struct HomeCatalogRowView: View {
    let row: CatalogRow
    let metas: [MetaPreview]?
    let above: [[String]]
    let model: HomeViewModel
    @EnvironmentObject private var app: AppModel

    var body: some View {
        let detail = "\(Display.typeLabel(row.catalog.type)) from \(row.addon.name)"
        if let metas {
            if !metas.isEmpty && !HomeRows.isRepeat(metas.map(\.id), above: above) {
                HomeSectionTitle(text: row.title, detail: detail)
                HomePosterRow(metas: metas) { app.open(.catalog(row)) }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HomeSectionTitle(text: row.title, detail: detail)
                HomePlaceholderRow()
            }
            .task { await model.load(row, app: app) }
        }
    }
}

/// A row of cards that scrolls to the side.
private struct HomeCardRow<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: HomeSizes.cardSpacing) { content }
                .padding(.horizontal, HomeSizes.gutter(sizeClass))
                .padding(.vertical, 8)
        }
    }
}

/// Tells that a new version is out. iOS does not let an app install an update, so the button opens the release page.
private struct HomeUpdateNotice: View {
    let release: Release
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeMessage(title: "Version \(release.version) is available", text: "Open the release page to get the new version.")
            Button("Open the release page") {
                if let url = URL(string: release.pageUrl) { openURL(url) }
            }
            .buttonStyle(.zSecondary)
            .padding(.leading, HomeSizes.gutter(sizeClass))
            .padding(.bottom, 8)
        }
    }
}

/// The values that make Home ask for its rows again.
private struct HomeTrigger: Hashable {
    var addons: AddonState
    var order: [String]
}

/// The values that make Home look for new episodes again.
private struct HomeEpisodesTrigger: Hashable {
    var shows: [String]
    var watched: Set<String>
    var loading: Bool
}

/// The VPN notice shows one time at each start of the app.
@MainActor
private enum HomeVpnNotice {
    static var shown = false
}

/// The rows, the titles of each row, and the new episodes of Home.
@MainActor
final class HomeViewModel: ObservableObject {
    /// All the rows of the addons in the order of the viewer, with the rows that are off.
    @Published private(set) var rows: [CatalogRow] = []
    @Published private(set) var types: [String] = []
    /// The titles of each row that loaded, by the key of the row. A row that did not answer has no titles.
    @Published private(set) var catalogs: [String: [MetaPreview]] = [:]
    @Published private(set) var newEpisodes: [NewEpisode] = []
    /// True when the art of the banner is there, or the wait for it is over.
    @Published var coverReady = false

    private var loading: Set<String> = []
    /// The rows that did not answer. They ask again when the addons change.
    private var failed: Set<String> = []

    func refresh(app: AppModel) async {
        let addons = app.container.addons
        let next = await app.homeRows()
        let nextTypes = await addons.types()
        var lists = catalogs
        for key in failed { lists[key] = nil }
        failed = []
        for row in next where lists[row.key] == nil {
            if let cached = await addons.cachedCatalog(row) { lists[row.key] = cached }
        }
        rows = next
        types = nextTypes
        catalogs = lists
    }

    func load(_ row: CatalogRow, app: AppModel) async {
        guard catalogs[row.key] == nil, loading.insert(row.key).inserted else { return }
        let metas: [MetaPreview]
        do {
            metas = try await app.container.addons.catalog(row)
        } catch {
            metas = []
            failed.insert(row.key)
        }
        loading.remove(row.key)
        catalogs[row.key] = metas
    }

    /// The first titles with art of the first row, for the banner.
    func featured(_ first: CatalogRow?) -> [MetaPreview] {
        guard let first, let metas = catalogs[first.key] else { return [] }
        return Self.pick(metas)
    }

    /// Home shows when the art of the banner is there, so that the screen does not jump.
    /// With no banner to wait for, Home shows at once.
    func isReady(app: AppModel, shown: [CatalogRow]) -> Bool {
        if coverReady || app.sources.isEmpty { return true }
        if !app.addonState.loading && shown.isEmpty { return true }
        if let first = shown.first, let metas = catalogs[first.key], Self.pick(metas).isEmpty { return true }
        return false
    }

    func loadNewEpisodes(app: AppModel) async {
        let followed = NewEpisodes.followed(app.library)
        let watched = app.library.watched
        newEpisodes = HomeNewEpisodeCache.get(followed, watched: watched)
        // It waits for the addons, because a show asked before they load has no episodes.
        guard !app.addonState.loading else { return }
        newEpisodes = await HomeNewEpisodeCache.load(followed, watched: watched, addons: app.container.addons)
    }

    private static func pick(_ metas: [MetaPreview]) -> [MetaPreview] {
        Array(metas.filter { $0.background != nil }.prefix(6))
    }
}

/// Keeps the new episodes for `keep` seconds, so that Home does not ask the addons on each visit.
@MainActor
private enum HomeNewEpisodeCache {
    static let keep: TimeInterval = 30 * 60
    private static var key: String?
    private static var time: Date?
    private static var metas: [Meta] = []

    private static func key(_ shows: [MetaPreview]) -> String {
        shows.map(\.id).joined(separator: ",")
    }

    private static var now: Int { Int((Date().timeIntervalSince1970 * 1000).rounded()) }

    static func get(_ shows: [MetaPreview], watched: Set<String>) -> [NewEpisode] {
        key == key(shows) ? NewEpisodes.find(metas, now: now, watched: watched) : []
    }

    static func load(_ shows: [MetaPreview], watched: Set<String>, addons: AddonRepository) async -> [NewEpisode] {
        let wanted = key(shows)
        if wanted != key || time.map({ Date().timeIntervalSince($0) > keep }) ?? true {
            let answers = await withTaskGroup(of: (Int, Meta).self) { group in
                for (index, show) in shows.enumerated() {
                    group.addTask {
                        let position = index
                        return (position, await addons.meta(show))
                    }
                }
                var all: [(Int, Meta)] = []
                for await answer in group { all.append(answer) }
                return all.sorted { $0.0 < $1.0 }.map(\.1)
            }
            guard !Task.isCancelled else { return get(shows, watched: watched) }
            metas = answers
            key = wanted
            // A show with no episodes is an addon that did not answer. Then the next visit asks again.
            time = answers.contains { !$0.videos.isEmpty } ? Date() : nil
        }
        return NewEpisodes.find(metas, now: now, watched: watched)
    }
}

/// The caption of a new episode card.
@MainActor
private enum HomeNewEpisodeText {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// For example "S2 E5 · Oct 12".
    static func caption(_ new: NewEpisode) -> String {
        let number: String
        if let season = new.video.season, let episode = new.video.episode {
            number = "S\(season) E\(episode)"
        } else {
            number = new.video.label
        }
        let date = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(new.released) / 1000))
        return "\(number) · \(date)"
    }
}
