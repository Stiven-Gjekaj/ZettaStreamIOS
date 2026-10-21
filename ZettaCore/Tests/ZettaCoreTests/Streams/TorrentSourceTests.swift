import Testing
@testable import ZettaCore

struct TorrentSourceTests {
    private let hash = "ABCDEF0123456789ABCDEF0123456789ABCDEF01"

    @Test func aDirectLinkHasNoTorrentSource() {
        #expect(AddonStream(url: "https://cdn.test/a.mp4", infoHash: hash).torrentSource == nil)
        #expect(AddonStream(infoHash: "short").torrentSource == nil)
    }

    @Test func theNameIsTheFirstLineOfTheTitle() {
        var stream = AddonStream(infoHash: hash, title: "Show S01E01\n👤 50 💾 1.2 GB")
        stream.fileIdx = 3
        stream.sources = ["tracker:udp://a.test:80/announce", "dht:abcdef"]
        let source = stream.torrentSource
        #expect(source == TorrentSource(infoHash: hash, fileIdx: 3, sources: stream.sources, name: "Show S01E01", filename: nil))
    }

    @Test func theFileNameOfTheAddonIsTheName() {
        var stream = AddonStream(infoHash: hash, title: "Pack\nmore")
        stream.hints.filename = "Show.S01E02.mkv"
        #expect(stream.torrentSource?.name == "Show.S01E02.mkv")
        #expect(stream.torrentSource?.filename == "Show.S01E02.mkv")
    }

    @Test func theMagnetAndTheTrackersComeFromTheSources() {
        let source = TorrentSource(infoHash: hash, sources: ["tracker:udp://a.test:80/announce", "dht:abcdef"], name: "Show")
        #expect(source.magnet.hasPrefix("magnet:?xt=urn:btih:\(hash.lowercased())&dn=Show&tr=udp%3A%2F%2Fa.test%3A80%2Fannounce"))
        #expect(source.trackers.first == "udp://a.test:80/announce")
        #expect(!source.trackers.contains { $0.hasPrefix("dht") })
    }
}
