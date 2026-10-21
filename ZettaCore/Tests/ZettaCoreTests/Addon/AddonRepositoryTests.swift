import Foundation
import Testing
@testable import ZettaCore

struct AddonRepositoryTests {
    /// Each addon has its own host, so the answers of two addons do not mix.
    private let good = StubServer()
    private let bad = StubServer()

    private let goodManifest = #"{"id":"g","name":"Good","types":["movie"],"resources":["stream"],"catalogs":[{"type":"movie","id":"top"},{"type":"movie","id":"find","extra":[{"name":"search","isRequired":true}]}]}"#
    private let subsManifest = #"{"id":"s","name":"Subs","types":["movie","series"],"idPrefixes":["tt"],"resources":["subtitles"],"catalogs":[]}"#

    /// One session that sends each request to the stub, whatever the host.
    private var client: AddonClient { AddonClient(session: good.session, userAgent: "ZettaStream/test") }

    private func repository(fallback: String? = nil) -> AddonRepository {
        AddonRepository(client: client, fallbackSubtitlesUrl: fallback)
    }

    private func sources(_ servers: StubServer...) -> [Source] {
        SourceList.parse(servers.map { $0.url("/manifest.json") }.joined(separator: "\n"))
    }

    @Test func aBadSourceIsAFailureAndTheGoodOneIsInstalled() async {
        good.reply(goodManifest)
        let repository = repository()
        await repository.install(sources(good, bad))
        let state = await repository.state
        #expect(!state.loading)
        #expect(state.addons.map(\.name) == ["Good"])
        #expect(Array(state.failures.keys) == [bad.url("/manifest.json")])
        #expect(await repository.homeRows().map(\.catalog.id) == ["top"])
    }

    private func all(_ stream: AsyncStream<StreamGroup>) async -> [StreamGroup] {
        var groups: [StreamGroup] = []
        for await group in stream { groups.append(group) }
        return groups
    }

    @Test func theStreamsOfAnAddonCountTheLinksThatCannotPlay() async throws {
        good.reply(goodManifest)
        let repository = repository()
        await repository.install(sources(good, bad))
        good.reply(#"{"streams":[{"url":"https://a.test/1.mp4"},{"infoHash":"x"},{"infoHash":"y"}]}"#)
        let groups = await all(repository.streams(type: "movie", videoId: "tt1"))
        let group = try #require(groups.first)
        #expect(groups.count == 1)
        #expect(group.streams.count == 1)
        // "x" and "y" are not 40 characters, so they are not torrents: they cannot play.
        #expect(group.hiddenTorrents == 0)
        #expect(group.unplayable == 2)
        #expect(good.paths.last == "/stream/movie/tt1.json")
    }

    @Test func torrentsComeWhenTheSettingIsOn() async throws {
        good.reply(goodManifest)
        let repository = repository()
        await repository.install(sources(good))
        let tt2 = #"{"streams":[{"url":"https://a.test/1.mp4"},{"infoHash":"abcdef0123456789abcdef0123456789abcdef01","fileIdx":2,"sources":["tracker:udp://t.test:1/announce"]}]}"#
        good.reply(#"{"streams":[{"url":"https://a.test/1.mp4"},{"infoHash":"x"},{"infoHash":"y"}]}"#)
        // "x" and "y" in tt1 are not 40 characters, so they are not torrents.
        #expect(await all(repository.streams(type: "movie", videoId: "tt1", withTorrents: true)).first?.streams.count == 1)
        good.reply(tt2)
        let withTorrents = try #require(await all(repository.streams(type: "movie", videoId: "tt2", withTorrents: true)).first)
        #expect(withTorrents.streams.count == 2)
        #expect(withTorrents.streams[1].fileIdx == 2)
        #expect(withTorrents.hiddenTorrents == 0)
        good.reply(tt2)
        let withoutTorrents = try #require(await all(repository.streams(type: "movie", videoId: "tt2")).first)
        #expect(withoutTorrents.streams.count == 1)
        #expect(withoutTorrents.hiddenTorrents == 1)
    }

    @Test func anAddonThatFailsGivesAGroupWithTheReason() async throws {
        good.reply(goodManifest)
        let repository = repository()
        await repository.install(sources(good))
        good.reply("{}", status: 503)
        let group = try #require(await all(repository.streams(type: "movie", videoId: "tt1")).first)
        #expect(group.streams.isEmpty)
        #expect(group.error == "HTTP 503 from \(good.url("/stream/movie/tt1.json"))")
    }

    @Test func eachGroupComesWhenItsAddonAnswers() async {
        let slow = StubServer()
        slow.reply(goodManifest.replacingOccurrences(of: "Good", with: "Slow"))
        good.reply(goodManifest)
        let repository = repository()
        await repository.install(sources(slow, good))
        slow.reply(#"{"streams":[{"url":"https://a.test/2.mp4"}]}"#, delay: 0.5)
        good.reply(#"{"streams":[{"url":"https://a.test/1.mp4"}]}"#)
        let names = await all(repository.streams(type: "movie", videoId: "tt1")).map(\.addon.name)
        #expect(names == ["Good", "Slow"])
    }

    @Test func oneAddonGivesItsPlayableStreams() async {
        good.reply(goodManifest)
        let repository = repository()
        await repository.install(sources(good))
        good.reply(#"{"streams":[{"url":"https://a.test/1.mp4"},{"ytId":"abc"}]}"#)
        #expect(await repository.streamsFrom(addonUrl: good.url("/manifest.json"), type: "movie", videoId: "tt1")?.count == 1)
        #expect(await repository.streamsFrom(addonUrl: "https://none.test/manifest.json", type: "movie", videoId: "tt1") == nil)
    }

    /// A time that a test sets.
    private final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var time = Date(timeIntervalSince1970: 0)
        var now: Date {
            get { lock.withLock { time } }
            set { lock.withLock { time = newValue } }
        }
    }

    @Test func aListOfStreamsStaysForAShortTimeOnly() async {
        let clock = TestClock()
        let repository = AddonRepository(client: client, fallbackSubtitlesUrl: nil, clock: { clock.now })
        let addon = Addon(manifestUrl: "https://a.test/manifest.json", manifest: Manifest(id: "a", name: "A"))
        let groups = [StreamGroup(addon: addon, streams: [AddonStream(url: "https://a.test/1.mp4")])]
        await repository.keepStreams(type: "series", videoId: "tt1:1:1", withTorrents: true, groups: groups)
        #expect(await repository.cachedStreams(type: "series", videoId: "tt1:1:1", withTorrents: true) == groups)
        #expect(await repository.cachedStreams(type: "series", videoId: "tt1:1:1", withTorrents: false) == nil)
        clock.now = Date(timeIntervalSince1970: AddonRepository.streamKeep)
        #expect(await repository.cachedStreams(type: "series", videoId: "tt1:1:1", withTorrents: true) == nil)
    }

    @Test func withNoSubtitleAddonTheFallbackGivesSubtitles() async {
        let subs = StubServer()
        subs.reply(subsManifest)
        subs.reply(#"{"subtitles":[{"id":"1","url":"https://s.test/1.srt","lang":"eng"}]}"#)
        good.reply(goodManifest)
        let repository = repository(fallback: subs.url("/manifest.json"))
        await repository.install(sources(good))
        #expect(await repository.subtitles(type: "movie", videoId: "tt1").map(\.url) == ["https://s.test/1.srt"])
        #expect(subs.paths == ["/manifest.json", "/subtitles/movie/tt1.json"])
    }

    @Test func withASubtitleAddonTheFallbackIsNotAsked() async {
        let subs = StubServer()
        let fallback = StubServer()
        subs.reply(subsManifest)
        let repository = repository(fallback: fallback.url("/manifest.json"))
        await repository.install(sources(subs))
        subs.reply(#"{"subtitles":[{"id":"1","url":"https://s.test/1.srt","lang":"eng"}]}"#)
        #expect(await repository.subtitles(type: "movie", videoId: "tt1").count == 1)
        #expect(fallback.paths.isEmpty)
    }

    @Test func aSlowSubtitleAddonDoesNotHoldBackTheOthers() async {
        let subs = StubServer()
        let slow = StubServer()
        subs.reply(subsManifest)
        slow.reply(#"{"id":"w","name":"Slow","types":["movie"],"idPrefixes":["tt"],"resources":["subtitles"],"catalogs":[]}"#)
        let repository = AddonRepository(client: client, fallbackSubtitlesUrl: nil, subtitleWait: .seconds(1))
        await repository.install(sources(subs, slow))
        #expect(await repository.state.addons.count == 2)
        subs.reply(#"{"subtitles":[{"id":"1","url":"https://s.test/1.srt","lang":"eng"}]}"#)
        slow.reply(#"{"subtitles":[{"id":"2","url":"https://s.test/2.srt","lang":"eng"}]}"#, delay: 5)
        let start = Date()
        #expect(await repository.subtitles(type: "movie", videoId: "tt1").map(\.url) == ["https://s.test/1.srt"])
        #expect(Date().timeIntervalSince(start) < 3)
    }

    @Test func anAddonThatKnowsOnlyImdbGetsTheImdbFormOfAnAnimeId() async {
        let subs = StubServer()
        subs.reply(subsManifest)
        let repository = repository()
        await repository.install(sources(subs))
        subs.reply(#"{"subtitles":[{"id":"3","url":"https://s.test/3.srt","lang":"eng"}]}"#)
        let found = await repository.subtitles(type: "anime", videoId: "kitsu:9:2", alias: ("series", "tt9:1:2"))
        #expect(found.map(\.url) == ["https://s.test/3.srt"])
        #expect(subs.lastRequest?.url?.absoluteString == subs.url("/subtitles/series/tt9%3A1%3A2.json"))
    }

    @Test func twoAddonsWithOneSubtitleGiveItOneTime() async {
        let one = StubServer()
        let two = StubServer()
        one.reply(subsManifest)
        two.reply(subsManifest)
        let repository = repository()
        await repository.install(sources(one, two))
        one.reply(#"{"subtitles":[{"url":"https://s.test/1.srt","lang":"eng"}]}"#)
        two.reply(#"{"subtitles":[{"url":"https://s.test/1.srt","lang":"eng"},{"url":"https://s.test/2.srt","lang":"fre"}]}"#)
        #expect(await repository.subtitles(type: "movie", videoId: "tt1").map(\.url) == ["https://s.test/1.srt", "https://s.test/2.srt"])
    }

    @Test func aCatalogKeepsItsLastAnswer() async throws {
        good.reply(goodManifest)
        let repository = repository()
        await repository.install(sources(good))
        let row = try #require(await repository.homeRows().first)
        #expect(await repository.cachedCatalog(row) == nil)
        good.reply(#"{"metas":[{"id":"tt1","type":"movie","name":"One"}]}"#)
        let metas = try await repository.catalog(row)
        #expect(metas.map(\.id) == ["tt1"])
        #expect(await repository.cachedCatalog(row) == metas)
    }

    private let metaManifest = #"{"id":"m","name":"Meta","types":["series"],"resources":["meta"],"catalogs":[]}"#

    @Test func aPlaceholderEpisodeListAsksTheNextAddon() async throws {
        let first = StubServer()
        let second = StubServer()
        first.reply(metaManifest)
        second.reply(metaManifest)
        let repository = repository()
        await repository.install(sources(first, second))
        first.reply(#"{"meta":{"id":"kitsu:1","type":"series","name":"One","videos":[{"id":"kitsu:1:1:1"}]}}"#)
        second.reply(#"{"meta":{"id":"kitsu:1","type":"series","name":"One","videos":[{"id":"kitsu:1:1"},{"id":"kitsu:1:2"}]}}"#)
        let meta = await repository.meta(MetaPreview(id: "kitsu:1", type: "series", name: "One"))
        #expect(meta.videos.map(\.id) == ["kitsu:1:1", "kitsu:1:2"])
    }

    @Test func withNoAnswerTheDetailsAreTheFactsOfTheCard() async {
        good.reply(metaManifest)
        let repository = repository()
        await repository.install(sources(good))
        good.reply("{}", status: 500)
        var card = MetaPreview(id: "tt1", type: "series", name: "One")
        card.poster = "https://p.test/1.jpg"
        card.genres = ["Drama"]
        card.aliases = ["Uno"]
        let meta = await repository.meta(card)
        #expect(meta.name == "One")
        #expect(meta.preview.poster == "https://p.test/1.jpg")
        #expect(meta.preview.genres == ["Drama"])
        #expect(meta.preview.aliases.isEmpty)
        #expect(meta.videos.isEmpty)
    }

    private func last(_ stream: AsyncStream<[MetaPreview]>) async -> (lists: Int, last: [MetaPreview]) {
        var count = 0
        var final: [MetaPreview] = []
        for await list in stream {
            count += 1
            final = list
        }
        return (count, final)
    }

    @Test func aSearchMergesTheAnswersAndTheSameSearchAnswersFromMemory() async {
        let other = StubServer()
        good.reply(goodManifest)
        other.reply(goodManifest.replacingOccurrences(of: "Good", with: "Other"))
        let clock = TestClock()
        let repository = AddonRepository(client: client, fallbackSubtitlesUrl: nil, clock: { clock.now })
        await repository.install(sources(good, other))
        good.reply(#"{"metas":[{"id":"tt1","type":"movie","name":"Dune","releaseInfo":"2021"},{"id":"tt2","type":"movie","name":"Dune Part Two"}]}"#)
        other.reply(#"{"metas":[{"id":"x:1","type":"movie","name":"Dune","releaseInfo":"2021","poster":"https://p.test/d.jpg"}]}"#, delay: 0.1)
        let first = await last(repository.search("Dune"))
        #expect(first.last.map(\.id) == ["tt1", "tt2"])
        #expect(first.last.first?.poster == "https://p.test/d.jpg")
        #expect(good.paths.last == "/catalog/movie/find/search=Dune.json")

        // Another form of the same text answers from memory, with one list and no request.
        let before = good.paths.count + other.paths.count
        let again = await last(repository.search("dune!"))
        #expect(again.lists == 1)
        #expect(again.last == first.last)
        #expect(good.paths.count + other.paths.count == before)

        // After the keep time, the search asks the addons again.
        clock.now = Date(timeIntervalSince1970: AddonRepository.searchKeep)
        good.reply(#"{"metas":[]}"#)
        other.reply(#"{"metas":[]}"#)
        #expect(await last(repository.search("Dune")).last.isEmpty)
        #expect(good.paths.count + other.paths.count == before + 2)
    }

    @Test func aSearchWithNoSearchCatalogGivesOneEmptyList() async {
        good.reply(metaManifest)
        let repository = repository()
        await repository.install(sources(good))
        let result = await last(repository.search("Dune"))
        #expect(result.lists == 1)
        #expect(result.last.isEmpty)
    }

    @Test func onlyTheAddonsOfTheListAreInstalled() async {
        good.reply(goodManifest)
        let repository = repository()
        let list = SourceList.parse("\(good.url("/manifest.json"))\nhttps://\(bad.host)/list.m3u")
        await repository.install(list)
        #expect(await repository.state.addons.map(\.name) == ["Good"])
        #expect(await repository.state.failures.isEmpty)
        #expect(bad.paths.isEmpty)
    }

    @Test func retryInstallsTheAddonsAgain() async {
        good.reply(goodManifest)
        let repository = repository()
        await repository.install(sources(good))
        let before = good.paths.count
        good.reply(goodManifest)
        await repository.retry()
        #expect(good.paths.count == before + 1)
        #expect(await repository.state.addons.map(\.name) == ["Good"])
    }

    @Test func aWatcherSeesTheLoadingAndTheEnd() async {
        good.reply(goodManifest)
        let repository = repository()
        let states = await repository.states()
        await repository.install(sources(good))
        var seen: [Bool] = []
        for await state in states {
            seen.append(state.loading)
            if !state.loading { break }
        }
        // The buffer keeps only the newest state, so the watcher can miss a step but never the end.
        #expect(seen.last == false)
    }

    @Test func theTypesComeInAFixedOrderAndEachKindOneTime() async {
        good.reply(#"{"id":"m","name":"Mixed","types":[],"resources":[],"catalogs":[{"type":"channel","id":"a"},{"type":"radio","id":"b"},{"type":"series","id":"c"},{"type":"tv","id":"d"},{"type":"movie","id":"e"}]}"#)
        let repository = repository()
        await repository.install(sources(good))
        #expect(await repository.types() == ["movie", "series", "tv", "radio"])
    }
}
