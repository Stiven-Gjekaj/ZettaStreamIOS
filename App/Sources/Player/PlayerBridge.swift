import Foundation
import VLCKit
import ZettaCore

/// An event of VLC, as a value that can go to the main thread.
enum PlayerEvent: Sendable {
    case state(VLCMediaPlayerState)
    case buffering(Float)
    case time
    /// The length in milliseconds. `VLCMedia.length` can stay 0 for an HLS stream, so the length comes from here.
    case length(Int64)
    case trackAdded(id: String, isText: Bool)
    case tracksChanged
    case snapshot
}

/// The delegate of VLC. VLC can call it on its own threads, so the receiver sends each event
/// to the main thread in order.
final class PlayerEventBridge: NSObject, VLCMediaPlayerDelegate, @unchecked Sendable {
    private let send: @Sendable (PlayerEvent) -> Void

    init(send: @escaping @Sendable (PlayerEvent) -> Void) {
        self.send = send
    }

    // The selectors are written out, so that a change of a Swift name in VLCKit does not lose an event.
    @objc(mediaPlayerStateChanged:)
    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) { send(.state(newState)) }

    @objc(mediaPlayerBufferingChanged:)
    func mediaPlayerBufferingChanged(_ progress: Float) { send(.buffering(progress)) }

    @objc(mediaPlayerTimeChanged:)
    func mediaPlayerTimeChanged(_ aNotification: Notification) { send(.time) }

    @objc(mediaPlayerLengthChanged:)
    func mediaPlayerLengthChanged(_ length: Int64) { send(.length(length)) }

    @objc(mediaPlayerSnapshot:)
    func mediaPlayerSnapshot(_ aNotification: Notification) { send(.snapshot) }

    @objc(mediaPlayerTrackAdded:withType:)
    func mediaPlayerTrackAdded(_ trackId: String, with trackType: VLCMedia.TrackType) {
        send(.trackAdded(id: trackId, isText: trackType == .text))
    }

    @objc(mediaPlayerTrackRemoved:withType:)
    func mediaPlayerTrackRemoved(_ trackId: String, with trackType: VLCMedia.TrackType) { send(.tracksChanged) }

    @objc(mediaPlayerTrackUpdated:withType:)
    func mediaPlayerTrackUpdated(_ trackId: String, with trackType: VLCMedia.TrackType) { send(.tracksChanged) }

    @objc(mediaPlayerTrackSelected:selectedId:unselectedId:)
    func mediaPlayerTrackSelected(_ trackType: VLCMedia.TrackType, selectedId: String, unselectedId: String) {
        send(.tracksChanged)
    }
}

/// Keeps the last error lines of VLC. VLC gives no error code, so the fault comes from these lines.
final class PlayerErrorLog: NSObject, VLCLogging, @unchecked Sendable {
    private let lock = NSLock()
    private var kept: [String] = []
    private var currentLevel: VLCLogLevel = .error

    var level: VLCLogLevel {
        get { lock.withLock { currentLevel } }
        set { lock.withLock { currentLevel = newValue } }
    }

    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        guard logLevel == .error, !FaultLog.isNoise(message) else { return }
        lock.withLock {
            kept.append(message)
            if kept.count > FaultLog.keptLines { kept.removeFirst(kept.count - FaultLog.keptLines) }
        }
    }

    var lines: [String] { lock.withLock { kept } }

    func clear() { lock.withLock { kept.removeAll() } }
}

/// What Picture in Picture asks of the player. The system calls it on the main thread, but the
/// protocol of VLC does not say so, so the player is behind a lock.
final class PictureInPictureMedia: NSObject, VLCPictureInPictureMediaControlling, @unchecked Sendable {
    private let lock = NSLock()
    private weak var current: VLCMediaPlayer?
    /// A live channel has no length, so the window shows no seek bar.
    private var live = false
    /// The length that the player events gave. `VLCMedia.length` can stay 0 for HLS.
    private var length: Int64 = 0

    func attach(_ player: VLCMediaPlayer?, live: Bool) {
        lock.withLock {
            current = player
            self.live = live
            length = 0
        }
    }

    func update(length: Int64) {
        lock.withLock { self.length = length }
    }

    private var player: VLCMediaPlayer? { lock.withLock { current } }

    func play() { player?.play() }
    func pause() { player?.pause() }

    func seek(by offset: Int64, completion: @escaping () -> Void) {
        guard let player, player.isSeekable else { return completion() }
        if !player.jump(withOffset: Int32(clamping: offset), completion: completion) { completion() }
    }

    func mediaLength() -> Int64 {
        let (live, known) = lock.withLock { (self.live, length) }
        if live { return 0 }
        return max(known, Int64(player?.media?.length.intValue ?? 0))
    }

    func mediaTime() -> Int64 { Int64(player?.time.intValue ?? 0) }
    func isMediaSeekable() -> Bool { !lock.withLock { live } && (player?.isSeekable ?? false) }
    func isMediaPlaying() -> Bool { player?.isPlaying ?? false }
}
