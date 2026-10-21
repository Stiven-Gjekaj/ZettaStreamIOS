import Foundation
import ZettaCore

/// The actions of the player that change the data of the app.
extension AppModel {
    /// The wait for the subtitle addons when the next episode loads.
    static let nextSubtitleWait: Duration = .seconds(4)

    /// The key of a stream in the memory of streams that did not start.
    func healthKey(_ video: VideoPlayback) -> String {
        StreamHealth.key(addonUrl: video.addonUrl, url: video.url, infoHash: video.torrent?.infoHash, fileIdx: video.torrent?.fileIdx)
    }

    /// Remembers a stream that did not start, so that the app chooses it last for one day.
    func streamFailed(_ video: VideoPlayback) {
        try? container.health.failed(key: healthKey(video), addonUrl: video.addonUrl ?? "")
    }

    /// A stream that played clears its mark and the marks of its addon.
    func streamPlayed(_ video: VideoPlayback) {
        try? container.health.played(key: healthKey(video), addonUrl: video.addonUrl ?? "")
    }

    /// Closes the player, and opens `route` when it is not nil.
    func closePlayer(opening route: Route? = nil) {
        playback = nil
        if let route { open(route) }
    }

    /// Closes the player and opens the list of streams of the video, so that the viewer chooses another source.
    func chooseSource(for video: VideoPlayback) {
        closePlayer(opening: .streams(VideoRequest(meta: video.meta, videoId: video.videoId, label: video.label, episodes: video.episodes)))
    }

    /// The playback of `target` from the same addon and the same kind of stream as `current`.
    /// Nil when the addon is not known or gives no stream for that episode.
    func sameSourcePlayback(from current: VideoPlayback, target: Video, label: String) async -> VideoPlayback? {
        guard let addonUrl = current.addonUrl,
              let addon = addonState.addons.first(where: { $0.manifestUrl == addonUrl }) else { return nil }
        let type = current.meta.type
        let repo = container.addons
        guard let streams = await repo.streamsFrom(addonUrl: addonUrl, type: type, videoId: target.id, withTorrents: settings.showTorrents),
              let stream = StreamOrder.pickSameSource(streams, bingeGroup: current.bingeGroup, streamName: current.streamName,
                                                      current: current.streamInfo, wasTorrent: current.torrent != nil)
        else { return nil }
        let alias = Display.imdbAlias(current.meta, videoId: target.id, episodes: current.episodes)
        let subtitles = await Self.withTimeLimit(Self.nextSubtitleWait) {
            await repo.subtitles(type: type, videoId: target.id, alias: alias)
        } ?? []
        var next = VideoPlayback(meta: current.meta, videoId: target.id, label: label, episodes: current.episodes,
                                 listed: ListedStream(addon: addon, stream: stream), subtitles: subtitles)
        next.bingeGroup = next.bingeGroup ?? current.bingeGroup
        next.streamName = next.streamName ?? current.streamName
        return next
    }

    /// The result of `work`, or nil when it takes longer than `limit`.
    private static func withTimeLimit<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async -> T) async -> T? {
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
}
