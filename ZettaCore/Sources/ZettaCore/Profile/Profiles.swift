import Foundation

/// One person who uses the app. `avatar` is the link of a picture, or nil for the first letter of the name.
public struct Profile: Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var avatar: String?

    public init(id: String, name: String, avatar: String? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar
    }
}

public struct ProfilesData: Hashable, Sendable {
    public var profiles: [Profile] = []
    /// The ID of the profile of the last time.
    public var last: String?

    public init(profiles: [Profile] = [], last: String? = nil) {
        self.profiles = profiles
        self.last = last
    }
}

// The JSON form of the Android app. A missing key takes its default, and a null is written.

extension Profile: Codable {
    enum CodingKeys: String, CodingKey { case id, name, avatar }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id), name: try c.decode(String.self, forKey: .name),
                  avatar: try c.decodeIfPresent(String.self, forKey: .avatar))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(avatar, forKey: .avatar)
    }
}

extension ProfilesData: Codable {
    enum CodingKeys: String, CodingKey { case profiles, last }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try c.decodeIfPresent([Profile].self, forKey: .profiles) ?? []
        last = try c.decodeIfPresent(String.self, forKey: .last)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(profiles, forKey: .profiles)
        try c.encode(last, forKey: .last)
    }
}

/// Keeps the profiles in `profiles.json` in `root`. Each profile has its own folder for its
/// library and its settings. The sources are the same for all profiles.
public final class ProfileStore: Sendable {
    public static let firstName = "Main"
    public static let maxName = 20
    public static let maxProfiles = 5

    private let root: URL
    private let store: JSONFile<ProfilesData>

    public init(root: URL) {
        self.root = root
        let file = root.appendingPathComponent("profiles.json")
        store = JSONFile(file: file) { Self.firstStart(root: root, file: file) }
    }

    public var profiles: ProfilesData { store.value }

    /// Gives the profiles now, and then each change.
    public func updates() -> AsyncStream<ProfilesData> { store.updates() }

    /// The folder of the library and the settings of one profile.
    public func folder(_ id: String) -> URL {
        Self.folder(root: root, id: id)
    }

    @discardableResult
    public func add(name: String, avatar: String?) throws -> Profile {
        let profile = Profile(id: Self.newId(), name: Self.clean(name), avatar: avatar)
        try store.update { $0.profiles.append(profile) }
        return profile
    }

    public func edit(_ id: String, name: String, avatar: String?) throws {
        try store.update { data in
            for index in data.profiles.indices where data.profiles[index].id == id {
                data.profiles[index].name = Self.clean(name)
                data.profiles[index].avatar = avatar
            }
        }
    }

    /// Removes a profile and its folder. The last profile stays, so the app always has one.
    @discardableResult
    public func delete(_ id: String) throws -> Bool {
        let removed = try store.update { data -> Bool in
            guard data.profiles.count > 1, data.profiles.contains(where: { $0.id == id }) else { return false }
            data.profiles.removeAll { $0.id == id }
            if data.last == id { data.last = nil }
            return true
        }
        if removed { try? FileManager.default.removeItem(at: folder(id)) }
        return removed
    }

    public func select(_ id: String) throws {
        try store.update { $0.last = id }
    }

    static func clean(_ name: String) -> String {
        let text = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxName))
        return text.isEmpty ? "Profile" : text
    }

    private static func newId() -> String {
        String(UUID().uuidString.lowercased().prefix(8))
    }

    private static func folder(root: URL, id: String) -> URL {
        root.appendingPathComponent("profiles").appendingPathComponent(id)
    }

    /// On the first start with profiles, the library and the settings of the older version
    /// move into the folder of a first profile, so nothing is lost.
    private static func firstStart(root: URL, file: URL) -> ProfilesData {
        let first = Profile(id: newId(), name: firstName)
        let dir = folder(root: root, id: first.id)
        let files = FileManager.default
        try? files.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in ["library.json", "settings.json"] {
            let old = root.appendingPathComponent(name)
            if files.fileExists(atPath: old.path) { try? files.moveItem(at: old, to: dir.appendingPathComponent(name)) }
        }
        let data = ProfilesData(profiles: [first], last: first.id)
        // When this write fails, the next change writes the file.
        if let text = try? JSONFile<ProfilesData>.encode(data) { try? SafeFile(file: file).write(text) }
        return data
    }
}
