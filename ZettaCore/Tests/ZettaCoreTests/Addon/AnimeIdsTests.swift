import Foundation
import Testing
@testable import ZettaCore

struct AnimeIdsTests {
    @Test func aMyAnimeListIdGivesItsNumberAndEpisode() {
        #expect(AnimeIds.mal("mal-61987:1:3")?.id == 61987)
        #expect(AnimeIds.mal("mal-61987:1:3")?.episode == 3)
        #expect(AnimeIds.mal("mal-61987:7")?.episode == 7)
        #expect(AnimeIds.mal("mal-61987")?.episode == nil)
        #expect(AnimeIds.mal("mal-61987")?.id == 61987)
    }

    @Test func anotherIdIsNotAMyAnimeListId() {
        #expect(AnimeIds.mal("tt0903747:1:1") == nil)
        #expect(AnimeIds.mal("kitsu:50021:1") == nil)
        #expect(AnimeIds.mal("mal-abc:1:1") == nil)
    }

    @Test func theKitsuFormHasNoSeason() {
        #expect(AnimeIds.kitsuVideoId(kitsu: 50021, episode: 3) == "kitsu:50021:3")
        #expect(AnimeIds.kitsuVideoId(kitsu: 50021, episode: nil) == "kitsu:50021")
    }

    private let mapping = #"{"data":[{"id":"9","type":"mappings"}],"included":[{"id":"50021","type":"anime"}]}"#

    @Test func theMapperReadsTheAnimeAndAsksOnlyOnce() async {
        let kitsu = StubServer()
        kitsu.reply(mapping)
        let mapper = KitsuMapper(session: kitsu.session, base: kitsu.url("/api/edge"))
        #expect(await mapper.kitsuId(mal: 61987) == 50021)
        #expect(await mapper.kitsuId(mal: 61987) == 50021)
        #expect(kitsu.paths == ["/api/edge/mappings"])
        let query = kitsu.lastRequest?.url?.query ?? ""
        #expect(query.contains("filter%5BexternalId%5D=61987"))
        #expect(query.contains("myanimelist%2Fanime"))
    }

    @Test func aFoundNumberIsOnTheDiskAtTheNextStart() async {
        let kitsu = StubServer()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("kitsu-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        kitsu.reply(mapping)
        kitsu.reply(#"{"data":[],"included":[]}"#)
        let first = KitsuMapper(session: kitsu.session, base: kitsu.url("/api/edge"), file: file)
        #expect(await first.kitsuId(mal: 61987) == 50021)
        #expect(await first.kitsuId(mal: 2) == nil)
        let next = KitsuMapper(session: kitsu.session, base: kitsu.url("/api/edge"), file: file)
        #expect(await next.kitsuId(mal: 61987) == 50021)
        #expect(kitsu.paths.count == 2)
        // The number that Kitsu did not know is asked again. The stub has no answer now.
        #expect(await next.kitsuId(mal: 2) == nil)
        #expect(kitsu.paths.count == 3)
    }

    @Test func aMappingWithNoAnimeGivesNil() async {
        let kitsu = StubServer()
        kitsu.reply(#"{"data":[],"included":[]}"#)
        let mapper = KitsuMapper(session: kitsu.session, base: kitsu.url("/api/edge"))
        #expect(await mapper.kitsuId(mal: 1) == nil)
    }

    @Test func aFailedRequestIsAskedAgain() async {
        let kitsu = StubServer()
        kitsu.reply("{}", status: 503)
        kitsu.reply(mapping)
        let mapper = KitsuMapper(session: kitsu.session, base: kitsu.url("/api/edge"))
        #expect(await mapper.kitsuId(mal: 61987) == nil)
        #expect(await mapper.kitsuId(mal: 61987) == 50021)
        #expect(kitsu.paths.count == 2)
    }

    @Test func theRepositoryAsksAKitsuAddonWithTheKitsuForm() async throws {
        let anime = StubServer()
        let kitsu = StubServer()
        kitsu.reply(mapping)
        anime.reply(#"{"id":"a","name":"Anime","types":["series"],"idPrefixes":["kitsu"],"resources":["stream"],"catalogs":[]}"#)
        let repository = AddonRepository(
            client: AddonClient(session: anime.session, userAgent: "ZettaStream/test"),
            fallbackSubtitlesUrl: nil,
            kitsu: KitsuMapper(session: kitsu.session, base: kitsu.url("/api/edge")))
        await repository.install(SourceList.parse(anime.url("/manifest.json")))
        anime.reply(#"{"streams":[{"url":"https://a.test/1.mp4"}]}"#)
        var groups: [StreamGroup] = []
        for await group in await repository.streams(type: "series", videoId: "mal-61987:1:3") { groups.append(group) }
        #expect(groups.first?.streams.count == 1)
        #expect(anime.paths.last == "/stream/series/kitsu:50021:3.json")

        anime.reply(#"{"streams":[{"url":"https://a.test/2.mp4"}]}"#)
        let one = try #require(await repository.streamsFrom(addonUrl: anime.url("/manifest.json"), type: "series", videoId: "mal-61987:1:4"))
        #expect(one.count == 1)
        #expect(anime.paths.last == "/stream/series/kitsu:50021:4.json")
        #expect(kitsu.paths.count == 1)
    }

    @Test func anImdbIdDoesNotAskKitsu() async {
        let kitsu = StubServer()
        let found = await AddonRepository.requests([], type: "movie", videoId: "tt1", kitsu: KitsuMapper(session: kitsu.session, base: kitsu.url("")))
        #expect(found.isEmpty)
        #expect(kitsu.paths.isEmpty)
    }
}
