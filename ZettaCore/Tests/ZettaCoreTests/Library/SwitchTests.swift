import Foundation
import Testing
@testable import ZettaCore

struct SwitchTests {
    @Test func eachProfileKeepsItsOwnLibraryAndSettings() throws {
        let root = try temporaryFolder()
        let a = root.appendingPathComponent("profiles/a")
        let b = root.appendingPathComponent("profiles/b")
        let library = Library(file: a.appendingPathComponent("library.json"))
        let settings = SettingsStore(file: a.appendingPathComponent("settings.json"))
        try library.toggleWatchlist(MetaPreview(id: "tt1", type: "movie", name: "One"))
        try settings.update { $0.directFirst = true }

        library.switchTo(b.appendingPathComponent("library.json"))
        settings.switchTo(b.appendingPathComponent("settings.json"))
        #expect(library.data.watchlist.isEmpty)
        #expect(settings.settings.directFirst == false)
        try library.toggleWatchlist(MetaPreview(id: "tt2", type: "movie", name: "Two"))

        library.switchTo(a.appendingPathComponent("library.json"))
        settings.switchTo(a.appendingPathComponent("settings.json"))
        #expect(library.data.watchlist.map(\.id) == ["tt1"])
        #expect(settings.settings.directFirst == true)
        #expect(Library(file: b.appendingPathComponent("library.json")).data.watchlist.map(\.id) == ["tt2"])
    }
}
