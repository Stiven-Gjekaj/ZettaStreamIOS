import Foundation
import Testing
@testable import ZettaCore

struct AddonClientTests {
    private let server = StubServer()
    private var client: AddonClient { AddonClient(session: server.session, userAgent: "ZettaStream/test") }

    private func installed() async throws -> Addon {
        server.reply(#"{"id":"t","name":"Test","types":["series"],"resources":["catalog","meta","stream"],"catalogs":[{"type":"series","id":"pop"}]}"#)
        return try await client.install(server.url("/manifest.json"))
    }

    @Test func installReadsTheManifestAndSendsTheUserAgent() async throws {
        let addon = try await installed()
        #expect(addon.name == "Test")
        #expect(server.paths == ["/manifest.json"])
        #expect(server.lastRequest?.value(forHTTPHeaderField: "User-Agent") == "ZettaStream/test")
    }

    @Test func catalogReadsTheMetasAndLeavesOutAnEmptyId() async throws {
        let addon = try await installed()
        server.reply(#"{"metas":[{"id":"tt1","type":"series","name":"One","releaseInfo":2020,"unknown":true},{"id":"","type":"series"}]}"#)
        let metas = try await client.catalog(addon, addon.manifest.catalogs[0])
        #expect(metas.count == 1)
        #expect(metas.first?.releaseInfo == "2020")
        #expect(server.paths.last == "/catalog/series/pop.json")
    }

    @Test func metaReadsTheEpisodesWithTheImdbNumbers() async throws {
        let addon = try await installed()
        server.reply(#"{"meta":{"id":"kitsu:1","type":"series","name":"One","videos":[{"id":"kitsu:1:1","title":"Pilot","season":1,"episode":1,"imdbSeason":2,"imdbEpisode":1}]}}"#)
        let meta = try #require(try await client.meta(addon, type: "series", id: "kitsu:1"))
        #expect(meta.videos.first?.label == "Pilot")
        #expect(meta.videos.first?.season == 2)
    }

    @Test func streamsReadEachEntry() async throws {
        let addon = try await installed()
        server.reply(#"{"streams":[{"url":"https://cdn.test/a.m3u8","name":"1080p"},{"infoHash":"abc"},{"ytId":"xyz"}]}"#)
        let streams = try await client.streams(addon, type: "series", videoId: "tt1:1:1")
        #expect(streams.count == 3)
        #expect(server.paths.last == "/stream/series/tt1:1:1.json")
    }

    @Test func anErrorStatusThrows() async throws {
        let addon = try await installed()
        server.reply("{}", status: 503)
        await #expect(throws: HTTPError.self) { try await client.streams(addon, type: "movie", videoId: "tt1") }
    }
}
