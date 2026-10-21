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

    private func named(_ name: String, torrent: Bool, seeds: Int = 50) -> AddonStream {
        torrent ? AddonStream(infoHash: String(repeating: "b", count: 40), name: "\(name) 👤 \(seeds)")
            : AddonStream(url: "https://cdn.test/\(name.count).mp4", name: name)
    }

    private func bestOf(_ preferDirect: Bool, _ streams: AddonStream...) -> String? {
        let name = StreamOrder.best(ListedStream.list(addon("A"), streams), preferDirect: preferDirect)?.stream.name
        return name.map { $0.components(separatedBy: " 👤")[0] }
    }

    @Test func aStreamAt1080pWinsOverHigherAndLower() {
        #expect(bestOf(true, named("2160p", torrent: false), named("720p", torrent: false), named("1080p", torrent: false)) == "1080p")
    }

    @Test func withNo1080pTheNearestLowerResolutionWins() {
        #expect(bestOf(true, named("2160p", torrent: false), named("480p", torrent: false), named("720p", torrent: false)) == "720p")
    }

    @Test func withNoKnownResolutionAHigherOneWins() {
        #expect(bestOf(true, named("web", torrent: false), named("2160p", torrent: false)) == "2160p")
    }

    @Test func theSettingChoosesTheKindAtTheSameResolution() {
        #expect(bestOf(true, named("1080p bt", torrent: true), named("1080p web", torrent: false)) == "1080p web")
        #expect(bestOf(false, named("1080p web", torrent: false), named("1080p bt", torrent: true)) == "1080p bt")
    }

    @Test func resolutionComesBeforeTheKind() {
        #expect(bestOf(true, named("720p web", torrent: false), named("1080p bt", torrent: true)) == "1080p bt")
    }

    @Test func aTorrentWithAlmostNoSeedersComesAfterADirectLink() {
        #expect(bestOf(false, named("1080p bt", torrent: true, seeds: 1), named("1080p web", torrent: false)) == "1080p web")
    }

    @Test func moreSeedersWinAmongTorrents() {
        #expect(bestOf(false, named("1080p a", torrent: true, seeds: 10), named("1080p b", torrent: true, seeds: 90)) == "1080p b")
    }

    @Test func noStreamGivesNothing() {
        #expect(StreamOrder.best([], preferDirect: true) == nil)
    }

    @Test func rankedPutsEveryStreamInTheOrderOfBest() {
        let streams = ListedStream.list(addon("A"), [named("720p", torrent: false), named("1080p", torrent: false), named("2160p", torrent: false)])
        #expect(StreamOrder.ranked(streams, preferDirect: true).map(\.stream.name) == ["1080p", "720p", "2160p"])
    }

    @Test func directLinksKeepTheOrderOfTheSourceList() {
        let streams = ListedStream.list(addon("A"), [named("1080p a", torrent: false), named("1080p bb", torrent: false)])
            + ListedStream.list(addon("B"), [named("1080p ccc", torrent: false)])
        #expect(StreamOrder.ranked(streams, preferDirect: true).map(\.stream.name) == ["1080p a", "1080p bb", "1080p ccc"])
    }

    @Test func anIdealStreamIs1080pOfThePreferredKind() {
        let direct = ListedStream(addon: addon("A"), stream: named("1080p web", torrent: false))
        #expect(StreamOrder.isIdeal(direct, preferDirect: true))
        #expect(!StreamOrder.isIdeal(direct, preferDirect: false))
        let weak = ListedStream(addon: addon("A"), stream: named("1080p bt", torrent: true, seeds: 2))
        #expect(!StreamOrder.isIdeal(weak, preferDirect: false))
    }

    private func sized(_ name: String, gb: Double, seeds: Int) -> AddonStream {
        AddonStream(infoHash: String(name.padding(toLength: 40, withPad: "x", startingAt: 0)), name: "\(name) 1080p", title: "👤 \(seeds) 💾 \(gb) GB")
    }

    @Test func aTorrentTooLargeToStreamComesAfterASmallerOne() {
        let streams = ListedStream.list(addon("A"), [sized("bluray", gb: 9.85, seeds: 71), sized("yts", gb: 1.51, seeds: 40)])
        let max = StreamOrder.streamableBytes(type: "movie")
        #expect(StreamOrder.best(streams, preferDirect: false, maxTorrentBytes: max)?.stream.name == "yts 1080p")
        #expect(StreamOrder.best(streams, preferDirect: false)?.stream.name == "bluray 1080p")
        #expect(!StreamOrder.isIdeal(streams[0], preferDirect: false, maxTorrentBytes: max))
    }

    @Test func anEpisodeHasASmallerLimitThanAFilm() {
        #expect(StreamOrder.streamableBytes(type: "series") < StreamOrder.streamableBytes(type: "movie"))
        #expect(StreamOrder.streamableBytes(type: " Film ") == StreamOrder.streamableBytes(type: "movie"))
    }

    private struct FakeHealth: StreamOrder.Health {
        let broken: AddonStream
        func failedRecently(_ listed: ListedStream) -> Bool { listed.stream == broken }
        func unreliable(addonUrl: String) -> Bool { addonUrl.contains("B.test") }
    }

    @Test func aStreamThatFailedComesLastAndAnUnreliableAddonComesLater() {
        let broken = named("1080p broken", torrent: false)
        let streams = ListedStream.list(addon("A"), [broken, named("720p ok", torrent: false)])
            + ListedStream.list(addon("B"), [named("1080p shaky", torrent: false)])
            + ListedStream.list(addon("C"), [named("1080p good", torrent: false)])
        let order = StreamOrder.ranked(streams, preferDirect: true, health: FakeHealth(broken: broken)).map(\.stream.name)
        #expect(order == ["1080p good", "1080p shaky", "720p ok", "1080p broken"])
    }
}
