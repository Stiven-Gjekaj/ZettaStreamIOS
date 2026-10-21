import Foundation
import Testing
@testable import ZettaCore

// The Android app has no test for this code. These tests hold the behaviour of LiveRepository.load.
/// A class, so that `deinit` removes the folder of each test.
final class LiveLoaderTests: Sendable {
    // 2026-10-08T10:30:00Z in milliseconds.
    private let now: Int64 = 1_791_455_400_000

    /// The session of one stub server also answers for the hosts of the others.
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("live-\(UUID().uuidString)")

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    private func loader(_ server: StubServer, at time: TimeInterval = 0) -> LiveLoader {
        LiveLoader(client: FileClient(session: server.session, userAgent: "ZettaStream/test", folder: folder,
                                      clock: { Date(timeIntervalSince1970: time) }))
    }

    @Test func aPlaylistKeepsOneHourAndAGuideSixHours() async {
        let list = StubServer(), guide = StubServer()
        let sources = [Source(url: list.url("/list.m3u"), kind: .playlist), Source(url: guide.url("/g.xml"), kind: .guide)]
        let playlist = "#EXTM3U\n#EXTINF:-1 tvg-id=\"news.test\",News\nhttps://s.test/news.m3u8"
        let xml = "<tv>\(programme("news.test", "Morning", "20261008100000", "20261008110000"))</tv>"
        for _ in 0..<3 { list.reply(playlist); guide.reply(xml) }
        _ = await loader(list, at: 0).load(sources, now: now)
        _ = await loader(list, at: LiveLoader.playlistKeep - 1).load(sources, now: now)
        #expect((list.paths.count, guide.paths.count) == (1, 1))
        _ = await loader(list, at: LiveLoader.playlistKeep).load(sources, now: now)
        #expect((list.paths.count, guide.paths.count) == (2, 1))
        let state = await loader(list, at: LiveLoader.guideKeep).load(sources, now: now)
        #expect((list.paths.count, guide.paths.count) == (3, 2))
        #expect(state.guide.nowAndNext("news.test", now: now).now?.title == "Morning")
        #expect(LiveLoader.playlistKeep == 3_600)
        #expect(LiveLoader.guideKeep == 21_600)
    }

    private func programme(_ channel: String, _ title: String, _ start: String, _ stop: String) -> String {
        #"<programme start="\#(start) +0000" stop="\#(stop) +0000" channel="\#(channel)"><title>\#(title)</title></programme>"#
    }

    @Test func loadsThePlaylistsThenTheGuidesAndKeepsTheFailures() async throws {
        let first = StubServer(), second = StubServer(), broken = StubServer(), linked = StubServer(), listed = StubServer()
        first.reply("""
            #EXTM3U x-tvg-url="\(linked.url("/a.xml"))"
            #EXTINF:-1 tvg-id="news.test" group-title="News",News
            https://s.test/news.m3u8
            """)
        second.reply("#EXTM3U\n#EXTINF:-1,Copy\nhttps://s.test/news.m3u8\n#EXTINF:-1 tvg-id=\"music.test\",Music\nhttps://s.test/music.m3u8")
        broken.reply("gone", status: 404)
        linked.reply("<tv>\(programme("news.test", "Morning", "20261008100000", "20261008110000"))\(programme("news.test", "Noon", "20261008110000", "20261008120000"))</tv>")
        listed.reply("<tv>\(programme("music.test", "Hits", "20261008100000", "20261008120000"))\(programme("other.test", "Other", "20261008100000", "20261008120000"))</tv>")

        let state = await loader(first).load([
            Source(url: first.url("/one.m3u"), kind: .playlist),
            Source(url: broken.url("/two.m3u"), kind: .playlist),
            Source(url: second.url("/three.m3u"), kind: .playlist),
            Source(url: listed.url("/epg.xml"), kind: .guide),
            Source(url: linked.url("/a.xml"), kind: .guide),
        ], now: now)

        #expect(state.loaded)
        #expect(!state.loading)
        #expect(state.channels.map(\.name) == ["News", "Music"])
        #expect(state.failures == [broken.url("/two.m3u"): "HTTP 404"])
        let news = state.guide.nowAndNext("news.test", now: now)
        #expect(news.now?.title == "Morning")
        #expect(news.next?.title == "Noon")
        #expect(state.guide.nowAndNext("music.test", now: now).now?.title == "Hits")
        #expect(state.guide.programmes("other.test") == [])
        // The guide URL is in the list and in the playlist, but it downloads one time.
        #expect(linked.paths == ["/a.xml"])
    }

    @Test func withNoGuideIdsNoGuideDownloads() async {
        let list = StubServer(), guide = StubServer()
        list.reply("#EXTM3U x-tvg-url=\"\(guide.url("/g.xml"))\"\n#EXTINF:-1,Plain\nhttps://s.test/plain.ts")
        let channels = Box()
        let state = await loader(list).load([Source(url: list.url("/list.m3u"), kind: .playlist)], now: now) { channels.set($0) }
        #expect(state.channels.map(\.url) == ["https://s.test/plain.ts"])
        #expect(channels.get().map(\.url) == ["https://s.test/plain.ts"])
        #expect(guide.paths == [])
        #expect(state.failures == [:])
    }

    @Test func aGuideThatFailsIsAFailure() async {
        let list = StubServer(), guide = StubServer()
        list.reply("#EXTM3U\n#EXTINF:-1 tvg-id=\"a\",A\nhttps://s.test/a.ts")
        guide.reply("<tv><programme")
        let state = await loader(list).load([
            Source(url: list.url("/list.m3u"), kind: .playlist),
            Source(url: guide.url("/g.xml"), kind: .guide),
        ], now: now)
        #expect(state.channels.count == 1)
        #expect(state.failures.keys.sorted() == [guide.url("/g.xml")])
        #expect(state.guide == .empty)
    }
}

/// Keeps the channels that the callback gets.
private final class Box: @unchecked Sendable {
    private let lock = NSLock()
    private var channels: [Channel] = []
    func set(_ value: [Channel]) { lock.withLock { channels = value } }
    func get() -> [Channel] { lock.withLock { channels } }
}
