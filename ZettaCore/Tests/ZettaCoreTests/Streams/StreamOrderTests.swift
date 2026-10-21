import Testing
@testable import ZettaCore

struct StreamOrderTests {
    private func addon(_ name: String) -> Addon {
        Addon(manifestUrl: "https://\(name).test/manifest.json", manifest: Manifest(id: name, name: name))
    }

    private func torrent(_ seeds: Int) -> AddonStream {
        AddonStream(infoHash: String(repeating: "a", count: 39) + "\(seeds % 10)", name: "T 👤 \(seeds)")
    }

    private func direct(_ name: String) -> AddonStream {
        AddonStream(url: "https://cdn.test/\(name).m3u8", name: name)
    }

    private var groups: [[ListedStream]] {
        [
            ListedStream.list(addon("A"), [torrent(5), direct("a1"), torrent(50)]),
            ListedStream.list(addon("B"), [torrent(20), direct("b1")]),
            ListedStream.list(addon("C"), []),
        ]
    }

    @Test func eachAddonKeepsItsPartWithTorrentsSortedBySeeders() {
        let sections = StreamOrder.sections(groups, directFirst: false)
        #expect(sections.map(\.title) == ["A", "B"])
        #expect(sections[0].streams.map(\.stream.name) == ["a1", "T 👤 50", "T 👤 5"])
    }

    @Test func directLinksFirstPutsAllTorrentsLastBySeeders() {
        let sections = StreamOrder.sections(groups, directFirst: true)
        #expect(sections.map(\.title) == ["Direct links", "Torrents"])
        #expect(sections[0].streams.map(\.stream.name) == ["a1", "b1"])
        #expect(sections[1].streams.map(\.info.seeders) == [50, 20, 5])
    }

    @Test func torrentsWithTheSameSeedersKeepTheirOrder() {
        let streams = [AddonStream(infoHash: String(repeating: "c", count: 40), name: "first"),
                       AddonStream(infoHash: String(repeating: "d", count: 40), name: "second")]
        let sections = StreamOrder.sections([ListedStream.list(addon("A"), streams)], directFirst: true)
        #expect(sections.map(\.title) == ["Torrents"])
        #expect(sections[0].streams.map(\.stream.name) == ["first", "second"])
    }
}
