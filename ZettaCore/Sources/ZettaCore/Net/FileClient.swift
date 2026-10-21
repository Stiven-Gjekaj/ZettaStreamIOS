import CryptoKit
import Foundation

/// Downloads a large file, such as a playlist or a TV guide.
///
/// Each file goes into the folder on the disk. A request with a keep time uses the
/// file again while it is newer than that time, as the Android app does.
public struct FileClient: Sendable {
    private let session: URLSession
    private let userAgent: String
    private let folder: URL
    private let clock: @Sendable () -> Date

    /// A test gives its own folder and clock.
    public init(session: URLSession = .shared, userAgent: String = ZettaCore.appName,
                folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent("files"),
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.session = session
        self.userAgent = userAgent
        self.folder = folder
        self.clock = clock
    }

    /// Downloads `url`. A gzip file is opened first, also when its name does not end in `.gz`.
    /// A status that is not 2xx throws `HTTPError`. See `file(_:keepFor:)` for `keepFor`.
    public func data(_ url: String, keepFor: TimeInterval? = nil) async throws -> Data {
        try Data(contentsOf: try await file(url, keepFor: keepFor), options: .mappedIfSafe)
    }

    /// Downloads `url` into a file on the disk and gives that file. A gzip file is opened first.
    /// When the file of an earlier download is newer than `keepFor` seconds, no download occurs.
    /// Nil always downloads. A failed download does not change the earlier file.
    public func file(_ url: String, keepFor: TimeInterval? = nil) async throws -> URL {
        guard let address = URL(string: url) else { throw URLError(.badURL) }
        let target = folder.appendingPathComponent(Self.name(url))
        if let keepFor, let date = try? target.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           clock().timeIntervalSince(date) < keepFor {
            return target
        }
        var request = URLRequest(url: address, timeoutInterval: 30)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        // The file goes to the disk and not into the memory, because a guide can be very large.
        let (download, response) = try await session.download(for: request)
        let manager = FileManager.default
        defer { try? manager.removeItem(at: download) }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HTTPError(status: http.statusCode, url: url)
        }
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let opened = folder.appendingPathComponent(UUID().uuidString)
        defer { try? manager.removeItem(at: opened) }
        if Gzip.isGzip(file: download) {
            try Gzip.decode(file: download, to: opened)
        } else {
            try manager.moveItem(at: download, to: opened)
        }
        try manager.setAttributes([.modificationDate: clock()], ofItemAtPath: opened.path)
        if manager.fileExists(atPath: target.path) {
            _ = try manager.replaceItemAt(target, withItemAt: opened)
        } else {
            try manager.moveItem(at: opened, to: target)
        }
        return target
    }

    /// The name of the file of a URL. A URL can be longer than a file name can be.
    static func name(_ url: String) -> String {
        SHA256.hash(data: Data(url.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
