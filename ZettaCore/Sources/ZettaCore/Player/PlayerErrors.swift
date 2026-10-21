import Foundation

/// The kind of fault that stops a stream. The Android app reads the error codes of Media3.
/// The iOS player gives other errors, so the app sorts each error into one of these kinds.
public enum PlaybackFault: Hashable, Sendable {
    /// The link gives a web page or a file that is not a video. In the middle of a video,
    /// this is damaged video data.
    case notVideo
    /// The server refuses the stream: a bad HTTP status, no file, or no permission.
    case refused
    /// The device cannot connect to the server, or the connection timed out.
    case noConnection
    /// Another network fault, for example a dropped connection.
    case network
    /// The device cannot decode the video.
    case decoder
    /// Another fault. The name shows in the message.
    case other(name: String)

    /// True for each fault of the network, so that a new try can help.
    public var isNetwork: Bool {
        switch self {
        case .refused, .noConnection, .network: return true
        default: return false
        }
    }
}

/// Tells the viewer in plain words why a stream does not play.
public enum PlayerErrors {
    /// The number of reconnects in a row, with no playback between them.
    public static let maxRetries = 3

    /// The time that a direct link gets to show its first frame. VLC has no read time
    /// limit, so a server that sends too slowly holds the player with no fault. After
    /// this time the stream counts as one that did not start, and the next one plays.
    /// A torrent gets more time, because its peers start to send slowly. Its time starts
    /// when the engine has the torrent information, so a torrent whose peers send no data
    /// does not hold the player.
    public static func startLimitMs(isTorrent: Bool) -> Int? {
        isTorrent ? 120_000 : 45_000
    }

    /// An HLS stream gets more tries, as each part of it does on Android.
    public static let hlsMaxRetries = 6

    /// The heights that an HLS stream steps down through after faults.
    public static let hlsHeights = [2160, 1440, 1080, 720, 480, 360]

    /// The time that a lower quality stays after faults, as on Android.
    public static let lowerQualityMs = 60_000

    /// The largest height for the reconnect of an HLS stream. After two faults in a row, the
    /// reconnect takes the next lower quality, as the Android app takes a part from a lower
    /// quality. Nil keeps the quality. `playing` is the height that played, or 0 when unknown.
    public static func hlsHeightLimit(retries: Int, playing: Int, limit: Int?) -> Int? {
        guard retries >= 2 else { return limit }
        let from = min(limit ?? Int.max, playing > 0 ? playing : Int.max)
        guard from != Int.max else { return 720 }
        return hlsHeights.first { $0 < from } ?? hlsHeights.last
    }

    /// Good playback this far past a fault ends the count of tries.
    public static let recoveredMs = 30_000

    /// The jump past damaged data in the middle of a video.
    public static let skipMs = 5_000

    /// A network fault reconnects at the same position, because a slow server
    /// often drops one request. Other faults do not change when the player tries
    /// again.
    public static func shouldRetry(_ fault: PlaybackFault, retries: Int) -> Bool {
        fault.isNetwork && retries < maxRetries
    }

    /// What the player does when a stream that played stops with a fault.
    public enum MidStream: Hashable, Sendable { case reconnect, skipAhead, nextSource, stop }

    /// A stream that played and then stops: first the player reconnects at the same position.
    /// Damaged data stops it again at the same place, so the second try jumps `skipMs` ahead.
    /// Then the next source continues at the same position. A device that cannot decode the
    /// video does not change with a new try, so it goes to the next source at once.
    /// An HLS stream gets `hlsMaxRetries` tries.
    public static func midStream(_ fault: PlaybackFault, retries: Int, hasNextSource: Bool, isHls: Bool = false) -> MidStream {
        let decoder = fault == .decoder
        if !decoder && retries == 0 { return .reconnect }
        if !decoder && retries == 1 && fault == .notVideo { return .skipAhead }
        if !decoder && retries < (isHls ? hlsMaxRetries : maxRetries) && fault.isNetwork { return .reconnect }
        return hasNextSource ? .nextSource : .stop
    }

    /// The message for a stream that played and then stopped.
    public static func describeMidStream(_ fault: PlaybackFault) -> String {
        fault == .notVideo ? "The stream sent damaged video data." : describe(fault)
    }

    /// The message for a stream that does not start.
    public static func describe(_ fault: PlaybackFault) -> String {
        switch fault {
        case .notVideo:
            return "This link gives a web page or a file that is not a video."
        case .refused:
            return "The server refuses this stream. The link can be old."
        case .noConnection:
            return "The device cannot connect to the server of this stream."
        case .decoder:
            return "This device cannot decode this video. Choose a source with an other codec, for example H.264."
        case .network:
            return "This stream does not play (network error)."
        case .other(let name):
            return "This stream does not play (\(name))."
        }
    }
}
