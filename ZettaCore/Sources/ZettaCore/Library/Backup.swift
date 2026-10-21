import Foundation

/// All that the viewer keeps on the device, in one file. The JSON form is the form of
/// the Android app, so a backup from one app restores in the other.
public struct BackupData: Hashable, Sendable {
    /// The name that each backup holds. It stays the same when the name of the app changes.
    public static let appName = "ZettaStream"

    public var app = BackupData.appName
    public var version = 1
    public var library = LibraryData()
    public var settings: ViewerSettings?
    /// The source list, one URL on each line.
    public var sources: String?

    public init(library: LibraryData = LibraryData(), settings: ViewerSettings? = nil, sources: String? = nil) {
        self.library = library
        self.settings = settings
        self.sources = sources
    }
}

extension BackupData: Codable {
    enum CodingKeys: String, CodingKey {
        case app, version, library, settings, sources
    }

    /// A missing key takes its default. An unknown key is ignored.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = try c.decodeIfPresent(String.self, forKey: .app) ?? BackupData.appName
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        library = try c.decodeIfPresent(LibraryData.self, forKey: .library) ?? LibraryData()
        settings = try c.decodeIfPresent(ViewerSettings.self, forKey: .settings)
        sources = try c.decodeIfPresent(String.self, forKey: .sources)
    }

    /// Each key is written, also a null, as the Android app does.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(app, forKey: .app)
        try c.encode(version, forKey: .version)
        try c.encode(library, forKey: .library)
        try c.encode(settings, forKey: .settings)
        try c.encode(sources, forKey: .sources)
    }
}

/// The error for a file that is not a backup.
public struct BackupError: Error, Equatable, CustomStringConvertible, LocalizedError {
    public let message: String
    public var description: String { message }
    public var errorDescription: String? { message }
}

/// Makes a backup of the library, the settings, and the source list, and restores one,
/// so a new install or a new device keeps the history of the viewer.
public struct Backup: Sendable {
    private let library: Library
    private let settings: SettingsStore
    private let sources: SourceStore

    public init(library: Library, settings: SettingsStore, sources: SourceStore) {
        self.library = library
        self.settings = settings
        self.sources = sources
    }

    public func export() throws -> String {
        let data = BackupData(library: library.data, settings: settings.settings, sources: SourceList.format(sources.sources))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(data), as: UTF8.self)
    }

    /// Replaces the data on the device with `text`. Gives a short report.
    /// A file that is not a backup throws, and changes nothing.
    @discardableResult
    public func restore(_ text: String) throws -> String {
        // The file must name the app and hold a library. Any other JSON file, such as {}, changes nothing.
        let bytes = Data(text.utf8)
        let root = try? JSONValue.parse(bytes)
        guard root?["app"] == .string(BackupData.appName), root?["library"]?.objectValue != nil else {
            throw BackupError(message: "This file is not a ZettaStream backup")
        }
        let data = try JSONDecoder().decode(BackupData.self, from: bytes)
        try library.replace(data.library)
        if let restored = data.settings { try settings.update { $0 = restored } }
        if let list = data.sources { try sources.replace(list) }
        func count(_ n: Int, _ word: String) -> String { "\(n) \(word)" + (n == 1 ? "" : "s") }
        let sourceCount = data.sources.map { SourceList.parse($0).count } ?? 0
        return "Restored \(count(data.library.watchlist.count, "title")) in the watchlist, "
            + "\(count(data.library.progress.count, "video")) in the history, and \(count(sourceCount, "source"))."
    }
}
