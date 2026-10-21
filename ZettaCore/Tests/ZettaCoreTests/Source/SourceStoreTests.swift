import Foundation
import Testing
@testable import ZettaCore

struct SourceStoreTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func replaceRemovesALineThatIsNotInTheNewList() throws {
        let file = try folder().appendingPathComponent("sources.txt")
        let store = SourceStore(file: file)
        try store.replace("https://a.test/manifest.json\nhttps://b.test/manifest.json")
        try store.replace("https://b.test/manifest.json")
        #expect(store.sources.map(\.url) == ["https://b.test/manifest.json"])
        #expect(SourceStore(file: file).sources.map(\.url) == ["https://b.test/manifest.json"])
    }

    @Test func theSeedOnlyFillsAStoreWithNoFile() throws {
        let root = try folder()
        let seed = "https://seed.test/manifest.json"
        #expect(SourceStore(file: root.appendingPathComponent("none.txt"), seed: seed).sources.map(\.url) == [seed])
        let empty = root.appendingPathComponent("empty.txt")
        try Data().write(to: empty)
        #expect(SourceStore(file: empty, seed: seed).sources.isEmpty)
    }
}
