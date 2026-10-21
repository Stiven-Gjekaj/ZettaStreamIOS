import Testing
@testable import ZettaCore

struct ListedStreamTests {
    private let addon = Addon(manifestUrl: "https://a.test/manifest.json", manifest: Manifest(id: "a", name: "A"))
    private let stream = AddonStream(infoHash: String(repeating: "a", count: 40), name: "T 👤 42")

    @Test func theInfoComesFromTheTextOfTheStream() {
        #expect(ListedStream(addon: addon, stream: stream).info.seeders == 42)
    }

    @Test func aGivenInfoStays() {
        #expect(ListedStream(addon: addon, stream: stream, info: StreamInfo(seeders: 1)).info.seeders == 1)
    }

    @Test func aListKeepsTheOrderOfTheAddon() {
        let listed = ListedStream.list(addon, [AddonStream(url: "https://a.test/1", name: "1"), AddonStream(url: "https://a.test/2", name: "2")])
        #expect(listed.map(\.stream.name) == ["1", "2"])
        #expect(listed.allSatisfy { $0.addon == addon })
    }
}
