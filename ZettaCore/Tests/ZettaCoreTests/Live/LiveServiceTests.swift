import Foundation
import Testing
@testable import ZettaCore

/// Asks each outside service of the app with the code of the app. A change of a service,
/// such as the end of the AniList API, then fails a test. These tests need the network,
/// so they run only with `ZS_LIVE=1`. The workflow "Services" runs them each day.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ZS_LIVE"] == "1", "ZS_LIVE is not 1"), .serialized)
struct LiveServiceTests {
    @Test func theProfilePicturesOfAnimeShow() async {
        let groups = await Avatars().featured()
        #expect((groups.first { $0.title == "Anime" }?.avatars.count ?? 0) >= 10)
        #expect((groups.first { $0.title == "TV and film" }?.avatars.count ?? 0) >= 10)
        let search = await Avatars().search("frieren")
        #expect(search.first { $0.title == "Anime" }?.avatars.contains { $0.name.contains("Frieren") } == true)
    }

    @Test func shikimoriGivesThePopularAnimeAndTheirCharacters() async throws {
        let (data, _) = try await URLSession.shared.data(for: Self.request("https://shikimori.io/api/animes?order=popularity&limit=1"))
        let id = try #require(Avatars.Parse.shikimoriAnime(data).first)
        let (roles, _) = try await URLSession.shared.data(for: Self.request("https://shikimori.io/api/animes/\(id)/roles"))
        #expect(!Avatars.Parse.shikimoriRoles(roles, base: "https://shikimori.io").isEmpty)
    }

    /// AniList turned off its API in October 2026. The app then uses Shikimori. This test
    /// tells when AniList works again.
    @Test func aniListAnswers() async throws {
        await withKnownIssue("The AniList API is off since October 2026.", isIntermittent: true) {
            var request = URLRequest(url: URL(string: "https://graphql.anilist.co")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(#"{"query":"{ Page(perPage: 5) { characters(sort: FAVOURITES_DESC) { name { full } image { large } } } }"}"#.utf8)
            let (data, _) = try await URLSession.shared.data(for: request)
            #expect(!Avatars.Parse.anilist(data).isEmpty)
        }
    }

    @Test func kitsuFindsTheKitsuIdOfAMyAnimeListId() async {
        #expect(await KitsuMapper().kitsuId(mal: 61987) == 50021)
    }

    @Test func aniSkipGivesTheOpeningOfAnAnimeEpisode() async {
        // Death Note, episode 2, of 23 minutes.
        let ranges = await SkipTimes().forVideo("kitsu:1376:2", durationMs: 1_380_000)
        #expect(ranges.contains { $0.kind == .opening })
    }

    @Test func openSubtitlesGivesSubtitlesOfAFilm() async throws {
        let repository = AddonRepository(client: AddonClient(), fallbackSubtitlesUrl: AddonRepository.openSubtitles)
        await repository.install([])
        // The Shawshank Redemption.
        #expect(await !repository.subtitles(type: "movie", videoId: "tt0111161").isEmpty)
    }

    /// GitHub gives each address 60 requests in each hour with no token, and the machines of CI
    /// share their addresses. The workflow gives its token, so this test is not refused there.
    @Test func gitHubGivesTheNewestRelease() async {
        let configuration = URLSessionConfiguration.ephemeral
        if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !token.isEmpty {
            configuration.httpAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        }
        let release = await UpdateChecker(session: URLSession(configuration: configuration)).latest()
        #expect(release?.version.isEmpty == false)
    }

    @Test func tvmazeGivesTheCastOfAShow() async throws {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://api.tvmaze.com/shows/169/cast")!)
        #expect(Avatars.Parse.tvmazeCast(data).count >= 5)
    }

    private static func request(_ url: String) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("ZettaStream", forHTTPHeaderField: "User-Agent")
        return request
    }
}
