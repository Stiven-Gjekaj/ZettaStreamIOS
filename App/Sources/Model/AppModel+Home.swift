import Foundation
import ZettaCore

/// The actions of the home screen, the catalog screen, and the home rows screen.
@MainActor
extension AppModel {
    /// The home rows in the order that the viewer chose. The list has the hidden rows too.
    func homeRows() async -> [CatalogRow] {
        await container.addons.homeRows(order: settings.rowOrder)
    }

    /// The rows that Home shows: the rows that are on, of the type of the filter.
    func shownHomeRows(_ rows: [CatalogRow]) -> [CatalogRow] {
        rows.filter { row in
            (homeFilter == nil || Display.typeKey(row.catalog.type) == homeFilter) && !settings.hiddenRows.contains(row.key)
        }
    }

    /// True when the type of `type` agrees with the filter of Home.
    func passesHomeFilter(_ type: String) -> Bool {
        homeFilter == nil || Display.typeKey(type) == homeFilter
    }

    /// Turns the row with `key` off or on.
    func toggleHomeRow(_ key: String) {
        updateSettings { settings in
            if settings.hiddenRows.contains(key) {
                settings.hiddenRows.remove(key)
            } else {
                settings.hiddenRows.insert(key)
            }
        }
    }

    /// Moves the row at `index` one place up (`step` -1) or down (`step` 1), and saves the order.
    func moveHomeRow(_ rows: [CatalogRow], index: Int, step: Int) {
        let order = HomeRows.move(rows, index: index, step: step)
        updateSettings { $0.rowOrder = order }
    }

    /// Plays a film at once. A series opens its page, where the viewer chooses the episode.
    func homeWatchNow(_ meta: MetaPreview) {
        if Display.typeKey(meta.type) == "movie" {
            open(.autoPlay(VideoRequest(meta: meta, videoId: meta.id, label: meta.name, episodes: [])))
        } else {
            open(.detail(meta))
        }
    }

    /// Continues a video from the history at its saved position.
    func homeResume(_ progress: WatchProgress) {
        open(.autoPlay(VideoRequest(meta: progress.meta, videoId: progress.videoId, label: progress.label, episodes: [])))
    }

    func homeIsInWatchlist(_ id: String) -> Bool {
        library.watchlist.contains { $0.id == id }
    }

    func homeIsWatched(_ id: String) -> Bool {
        library.watched.contains(id)
    }

    /// Turns off the VPN notice at start.
    func homeHideVpnNotice() {
        updateSettings { $0.vpnNotice = false }
    }

    /// Installs each addon again, for example after the network comes back.
    func homeRetryAddons() {
        let addons = container.addons
        Task { await addons.retry() }
    }
}
