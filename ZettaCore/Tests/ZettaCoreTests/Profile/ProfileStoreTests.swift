import Foundation
import Testing
@testable import ZettaCore

struct ProfileStoreTests {
    private let root: URL
    private let files = FileManager.default

    init() throws {
        root = try temporaryFolder()
    }

    @Test func theFirstStartMovesTheOldFilesIntoTheFirstProfile() throws {
        try Data(#"{"watchlist":[]}"#.utf8).write(to: root.appendingPathComponent("library.json"))
        try Data("{}".utf8).write(to: root.appendingPathComponent("settings.json"))
        let store = ProfileStore(root: root)
        let first = try #require(store.profiles.profiles.single)
        #expect(first.name == ProfileStore.firstName)
        #expect(store.profiles.last == first.id)
        #expect(files.fileExists(atPath: store.folder(first.id).appendingPathComponent("library.json").path))
        #expect(files.fileExists(atPath: store.folder(first.id).appendingPathComponent("settings.json").path))
        #expect(!files.fileExists(atPath: root.appendingPathComponent("library.json").path))
        #expect(ProfileStore(root: root).profiles.profiles.single == first)
    }

    @Test func aProfileCanBeAddedEditedAndDeletedButNotTheLast() throws {
        let store = ProfileStore(root: root)
        let first = try #require(store.profiles.profiles.single)
        let kid = try store.add(name: "  Kid  ", avatar: "https://a.test/a.png")
        #expect(kid.name == "Kid")
        try store.edit(kid.id, name: "", avatar: nil)
        #expect(store.profiles.profiles.last == Profile(id: kid.id, name: "Profile", avatar: nil))
        try store.select(kid.id)
        try files.createDirectory(at: store.folder(kid.id), withIntermediateDirectories: true)
        #expect(try store.delete(kid.id))
        #expect(!files.fileExists(atPath: store.folder(kid.id).path))
        #expect(store.profiles.last == nil)
        #expect(try !store.delete(first.id))
        #expect(ProfileStore(root: root).profiles.profiles == [first])
    }

    @Test func aLongNameIsCutAndAnUnknownProfileIsNotDeleted() throws {
        let store = ProfileStore(root: root)
        let profile = try store.add(name: String(repeating: "a", count: 30), avatar: nil)
        #expect(profile.name.count == ProfileStore.maxName)
        #expect(try !store.delete("none"))
        #expect(store.profiles.profiles.count == 2)
    }

    @Test func theFileHasTheKeysOfTheAndroidApp() throws {
        try Data(#"{"profiles":[{"id":"ab12cd34","name":"Main","avatar":null,"new":1}],"last":"ab12cd34"}"#.utf8)
            .write(to: root.appendingPathComponent("profiles.json"))
        let store = ProfileStore(root: root)
        #expect(store.profiles == ProfilesData(profiles: [Profile(id: "ab12cd34", name: "Main")], last: "ab12cd34"))
        try store.add(name: "Kid", avatar: nil)
        let saved = try JSONValue.parse(Data(contentsOf: root.appendingPathComponent("profiles.json")))
        #expect(Set(try #require(saved.objectValue).keys) == ["profiles", "last"])
        #expect(Set(try #require(saved["profiles"]?.arrayValue?.last?.objectValue).keys) == ["id", "name", "avatar"])
    }
}
