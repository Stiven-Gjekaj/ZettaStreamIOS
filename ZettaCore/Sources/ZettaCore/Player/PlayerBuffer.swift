import Foundation

/// How much video the player keeps ready. After a stall, the default starts
/// again with a small part ready, so a connection that is only a little slower
/// than the video stops every few seconds. A larger buffer after a stall
/// gives fewer and shorter stops. A torrent gets more, because its speed
/// changes more.
public struct PlayerBuffer: Hashable, Sendable {
    /// The player always tries to keep this much video ready.
    public var minMs: Int
    /// The player stops the download when this much video is ready.
    public var maxMs: Int
    /// The video that must be ready before playback starts.
    public var forPlaybackMs: Int
    /// The video that must be ready before playback starts again after a stall.
    public var afterStallMs: Int

    public init(minMs: Int, maxMs: Int, forPlaybackMs: Int, afterStallMs: Int) {
        self.minMs = minMs
        self.maxMs = maxMs
        self.forPlaybackMs = forPlaybackMs
        self.afterStallMs = afterStallMs
    }

    public static func of(isTorrent: Bool) -> PlayerBuffer {
        PlayerBuffer(
            minMs: 30_000,
            maxMs: isTorrent ? 120_000 : 90_000,
            forPlaybackMs: isTorrent ? 6_000 : 2_500,
            afterStallMs: isTorrent ? 20_000 : 12_000
        )
    }
}
