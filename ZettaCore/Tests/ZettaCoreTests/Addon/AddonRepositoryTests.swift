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
