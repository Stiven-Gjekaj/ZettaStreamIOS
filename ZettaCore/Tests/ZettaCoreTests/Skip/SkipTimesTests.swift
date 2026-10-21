import Foundation
import Testing
@testable import ZettaCore

struct SkipTimesTests {
    private let server = StubServer()
    private var times: SkipTimes {
        SkipTimes(session: server.session, kitsuBase: server.url("/kitsu"), aniSkipBase: server.url("/aniskip"))
    }

    private let mappings = #"{"data":[{"attributes":{"externalSite":"myanimelist/anime","externalId":"1535"}}]}"#
    private let answer = #"{"found":true,"results":[{"interval":{"startTime":10,"endTime":100},"skipType":"op"}]}"#

    @Test func asksKitsuThenAniSkipWithTheLengthOfTheVideo() async throws {
        server.reply(mappings)
        server.reply(answer)
        let ranges = await times.forVideo("kitsu:1376:5", durationMs: 1_420_999)
        #expect(ranges == [SkipRange(kind: .opening, start: 10_000, end: 100_000)])
        #expect(server.paths == ["/kitsu/anime/1376/mappings", "/aniskip/skip-times/1535/5"])
        let url = try #require(server.lastRequest?.url)
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(query.filter { $0.name == "types[]" }.map(\.value) == ["op", "ed", "recap", "mixed-op", "mixed-ed"])
        #expect(query.first { $0.name == "episodeLength" }?.value == "1420")
        #expect(server.lastRequest?.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func theMalIdIsKeptForTheNextEpisode() async {
        let times = times
        server.reply(mappings)
        server.reply(answer)
        server.reply(answer)
        _ = await times.forVideo("kitsu:1376:5", durationMs: 0)
        _ = await times.forVideo("kitsu:1376:6", durationMs: 0)
        #expect(server.paths == ["/kitsu/anime/1376/mappings", "/aniskip/skip-times/1535/5", "/aniskip/skip-times/1535/6"])
    }

    @Test func anIdThatIsNotKitsuAsksNothing() async {
        #expect(await times.forVideo("tt0903747:1:2", durationMs: 1_000).isEmpty)
        #expect(server.paths.isEmpty)
    }

    @Test func anErrorStatusOrNoMappingGivesNoTimes() async {
        server.reply("{}", status: 404)
        #expect(await times.forVideo("kitsu:1:1", durationMs: 1_000).isEmpty)
        server.reply(#"{"data":[]}"#)
        #expect(await times.forVideo("kitsu:1:1", durationMs: 1_000).isEmpty)
        #expect(server.paths == ["/kitsu/anime/1/mappings", "/kitsu/anime/1/mappings"])
    }

    @Test func aFailedConnectionGivesNoTimes() async {
        // The server has no answer, so the connection fails.
        #expect(await times.forVideo("kitsu:1:1", durationMs: 1_000).isEmpty)
    }
}
