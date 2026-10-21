import SwiftUI
import UIKit
import ZettaCore

/// The actions of the title page, the streams screen, and the auto play screen.
extension AppModel {
    /// The number of next best streams that the player keeps, in case a stream fails.
    static let streamFallbacks = 5

    /// The number of addons that give streams for this video.
    func streamAddonCount(_ request: VideoRequest) -> Int {
        addonState.addons.filter { $0.supports("stream", type: request.meta.type, id: request.videoId) }.count
    }

    /// All streams of the groups, best first, as the auto play screen chooses them.
    func rankedStreams(_ groups: [StreamGroup], type: String) -> [ListedStream] {
        StreamOrder.ranked(groups.flatMap { ListedStream.list($0.addon, $0.streams) },
                           preferDirect: settings.directFirst,
                           maxTorrentBytes: StreamOrder.streamableBytes(type: type),
                           health: container.health)
    }

    /// Plays one stream of the list. The next best streams are the fallbacks of the player.
    func playStream(_ listed: ListedStream, of request: VideoRequest, subtitles: [Subtitle], ranked: [ListedStream]) {
        let fallbacks = ranked.filter { $0 != listed }.prefix(Self.streamFallbacks)
        play(.video(VideoPlayback(meta: request.meta, videoId: request.videoId, label: request.label,
                                  episodes: request.episodes, listed: listed, subtitles: subtitles,
                                  fallbacks: Array(fallbacks))))
    }

    /// Removes the top screen of `tab`, and opens `route` in its place when it is not nil.
    /// The tab is the one of the screen, because the viewer can change the tab in the meantime.
    func closeTop(of tab: Tab, opening route: Route? = nil) {
        var path = paths[tab] ?? NavigationPath()
        if !path.isEmpty { path.removeLast() }
        if let route { path.append(route) }
        paths[tab] = path
    }

    func toggleDirectFirst() {
        updateSettings { $0.directFirst.toggle() }
    }

    /// Opens a YouTube video. The link opens the YouTube app when it is on the device.
    func openTrailer(_ youTubeId: String) {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(youTubeId)") else { return }
        UIApplication.shared.open(url) { [weak self] opened in
            if !opened { self?.show("No app on this device plays YouTube videos") }
        }
    }
}
