import Foundation
import ZettaCore

/// What the player plays.
enum Playback: Identifiable, Hashable {
    case video(VideoPlayback)
    case live(channels: [Channel], index: Int)

    var id: String {
        switch self {
        case .video(let video): "video:\(video.videoId):\(video.url):\(video.torrent?.infoHash ?? "")"
        case .live(let channels, let index): "live:\(channels[index].url)"
        }
    }
}

struct VideoPlayback: Hashable {
    var meta: MetaPreview
    var videoId: String
    var label: String
    var url: String
    var headers: [String: String]
    var subtitles: [Subtitle]
    var episodes: [Video]
    /// The addon that gave the stream, so that the next episode can come from the same source.
    var addonUrl: String?
    var bingeGroup: String?
    var streamName: String?
    /// What the text of the stream said, so that the next episode can match it.
    var streamInfo: StreamInfo?
    /// A torrent stream: the engine gives the local URL when the player starts.
    var torrent: TorrentSource?
    /// A short name of the stream, which the player shows at the start.
    var sourceLabel: String?
    /// The next best streams, in order. The player tries them when this stream fails at the start.
    var fallbacks: [ListedStream] = []

    /// Makes the playback of one stream from the list.
    init(meta: MetaPreview, videoId: String, label: String, episodes: [Video], listed: ListedStream,
         subtitles: [Subtitle], fallbacks: [ListedStream] = []) {
        self.meta = meta
        self.videoId = videoId
        self.label = label
        self.episodes = episodes
        url = listed.stream.url ?? ""
        headers = listed.stream.requestHeaders
        var seen = Set<String>()
        self.subtitles = (listed.stream.subtitles + subtitles).filter { seen.insert($0.url).inserted }
        addonUrl = listed.addon.manifestUrl
        bingeGroup = listed.stream.hints.bingeGroup
        streamName = listed.stream.name
        streamInfo = listed.info
        torrent = listed.stream.torrentSource
        sourceLabel = StreamOrder.shortLabel(listed)
        self.fallbacks = fallbacks
    }
}

/// The streams of one video, which the streams screen and the auto play screen show.
struct VideoRequest: Hashable {
    var meta: MetaPreview
    var videoId: String
    var label: String
    var episodes: [Video]
}
