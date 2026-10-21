import Foundation
import ZettaTorrent

/// The state of one torrent that plays. The Go engine gives it as JSON.
struct TorrentStats: Decodable, Sendable, Equatable {
    /// The peers that send or receive data.
    let peers: Int
    /// The connected peers that have the full torrent.
    let seeders: Int
    /// The download speed in bytes per second.
    let downloadRate: Int64
    /// The downloaded bytes of the file that plays.
    let fileDone: Int64
    /// The size of the file that plays.
    let fileSize: Int64
    /// The last position that the player read.
    let readPosition: Int64
    /// The downloaded bytes after the read position, up to the first missing piece.
    let bufferAhead: Int64
    /// The size of the window that downloads ahead of the read position.
    let window: Int64
}

/// An error of the torrent engine.
struct TorrentError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}

/// The torrent engine. It is anacrolix/torrent in Go, bound with gomobile.
///
/// The engine downloads one file of a torrent and serves it on 127.0.0.1, so
/// that the player plays it before the download is complete. The Go calls
/// can block, so each call runs on a background queue, not on the main
/// thread.
final class TorrentEngine: Sendable {
    static let shared = TorrentEngine()

    /// The default upload limit: 4 KB/s. Peers send less to a client that sends nothing.
    static let defaultUploadLimit = 4 * 1024

    private let queue = DispatchQueue(label: "io.github.stivengjekaj.zettastream.torrent", qos: .userInitiated, attributes: .concurrent)

    private init() {}

    /// Starts the client and the local server. The engine removes the data of
    /// an earlier run in `dataDir`. `uploadLimit` is in bytes per second, and
    /// 0 means no limit. A second call does nothing.
    func start(dataDir: URL, uploadLimit: Int = TorrentEngine.defaultUploadLimit) async throws {
        try await run {
            var error: NSError?
            if !ZettatorrentStart(dataDir.path, uploadLimit, &error) {
                throw TorrentError(message: error?.localizedDescription ?? "The torrent engine did not start")
            }
        }
    }

    /// The port of the local server, or 0 before `start`.
    var port: Int { ZettatorrentPort() }

    /// Adds the torrent, waits for its information, and starts the download
    /// of one file. It gives the local URL of that file.
    ///
    /// - Parameters:
    ///   - infoHash: The 40 digit hex info hash.
    ///   - fileIdx: The index of the file that the addon gave, or nil. When
    ///     it is nil or not a video, the engine takes the largest video.
    ///   - trackers: The `sources` of the addon. The engine keeps the
    ///     `tracker:` items and adds public trackers.
    ///   - name: The name of the torrent, or nil.
    ///
    /// This can take up to a minute. When the task is cancelled, the engine
    /// stops the torrent.
    func play(infoHash: String, fileIdx: Int?, trackers: [String], name: String?) async throws -> URL {
        try await withTaskCancellationHandler {
            let text = try await run { () throws -> String in
                var error: NSError?
                let url = ZettatorrentPlay(infoHash, fileIdx ?? -1, trackers.joined(separator: "\n"), name ?? "", &error)
                if let error {
                    throw TorrentError(message: error.localizedDescription)
                }
                return url
            }
            // The cancel can come before Play added the torrent. Stop it here too.
            if Task.isCancelled {
                ZettatorrentStop(infoHash)
                throw CancellationError()
            }
            guard let url = URL(string: text) else {
                throw TorrentError(message: "The torrent engine gave a bad URL: \(text)")
            }
            return url
        } onCancel: {
            ZettatorrentStop(infoHash)
        }
    }

    /// The state of a torrent that plays, or nil when it is not open.
    func stats(infoHash: String) async -> TorrentStats? {
        let text = await run { ZettatorrentStats(infoHash) }
        guard let data = text.data(using: .utf8), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(TorrentStats.self, from: data)
    }

    /// Stops the torrent and deletes its files. The app does not seed after playback.
    func stop(infoHash: String) async {
        await run { ZettatorrentStop(infoHash) }
    }

    /// Stops all torrents and deletes their files.
    func stopAll() async {
        await run { ZettatorrentStopAll() }
    }

    private func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    private func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: work())
            }
        }
    }
}
