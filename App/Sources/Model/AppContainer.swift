import Foundation
import ZettaCore

/// Makes the objects that live as long as the app.
final class AppContainer: Sendable {
    let files: URL
    let caches: URL
    let client: AddonClient
    let sources: SourceStore
    let addons: AddonRepository
    let live: LiveLoader
    /// Each profile has its own library and settings. The sources are the same for all.
    let profiles: ProfileStore
    let library: Library
    let settings: SettingsStore
    let avatars: Avatars
    let updates: UpdateChecker
    let skipTimes: SkipTimes
    let health: StreamHealth
    let backup: Backup

    init() {
        let manager = FileManager.default
        files = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        caches = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? manager.createDirectory(at: files, withIntermediateDirectories: true)
        let userAgent = "ZettaStream/\(AppInfo.version)"
        client = AddonClient(userAgent: userAgent)
        sources = SourceStore(file: files.appendingPathComponent("sources.txt"))
        addons = AddonRepository(client: client)
        live = LiveLoader(client: FileClient(userAgent: userAgent))
        profiles = ProfileStore(root: files)
        let data = profiles.profiles
        let current = data.profiles.first { $0.id == data.last } ?? data.profiles[0]
        library = Library(file: profiles.folder(current.id).appendingPathComponent("library.json"))
        settings = SettingsStore(file: profiles.folder(current.id).appendingPathComponent("settings.json"))
        avatars = Avatars()
        updates = UpdateChecker(userAgent: userAgent)
        skipTimes = SkipTimes(userAgent: userAgent)
        health = StreamHealth(file: files.appendingPathComponent("health.json"))
        backup = Backup(library: library, settings: settings, sources: sources)
    }

    /// Changes to the library and the settings of `id`.
    func selectProfile(_ id: String) throws {
        try profiles.select(id)
        library.switchTo(profiles.folder(id).appendingPathComponent("library.json"))
        settings.switchTo(profiles.folder(id).appendingPathComponent("settings.json"))
    }
}

enum AppInfo {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
}
