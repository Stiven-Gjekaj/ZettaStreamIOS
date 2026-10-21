import Foundation
import Testing
@testable import ZettaCore

struct AddonDiskTests {
    private let server = StubServer()
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("addons-\(UUID().uuidString)")
    private let manifest = #"{"id":"g","name":"Good","types":["movie"],"resources":["stream","catalog"],"catalogs":[{"type":"movie","id":"top"}]}"#

    private func repository() -> AddonRepository {
        AddonRepository(client: AddonClient(session: server.session, userAgent: "ZettaStream/test"), fallbackSubtitlesUrl: nil,
                        disk: AddonDisk(folder: folder), catalogSaveDelay: .milliseconds(10))
    }

    private var sources: [Source] { SourceList.parse(server.url("/manifest.json")) }

    @Test func anAddonWithNoAnswerWorksWithItsManifestFromTheDisk() async {
        server.reply(manifest)
        await repository().install(sources)
        // The next start has no network: the stub has no answer.
        let next = repository()
        await next.install(sources)
        let state = await next.state
        #expect(state.addons.map(\.name) == ["Good"])
        #expect(state.failures.isEmpty)
    }

    @Test func theAddonsOfTheDiskShowBeforeTheNetworkAnswers() async throws {
        server.reply(manifest)
        await repository().install(sources)
        server.reply(manifest, delay: 0.5)
        let next = repository()
        let install = Task { await next.install(sources) }
        try await Task.sleep(for: .milliseconds(100))
        let early = await next.state
        #expect(early.loading)
        #expect(early.addons.map(\.name) == ["Good"])
        await install.value
        #expect(await !next.state.loading)
    }

    @Test func aSourceThatLeavesTheListLeavesTheDisk() async {
        server.reply(manifest)
        await repository().install(sources)
        await repository().install([])
        let next = repository()
        await next.install(sources)
        #expect(await next.state.addons.isEmpty)
        #expect(await next.state.failures.count == 1)
    }

    @Test func theLastAnswerOfACatalogIsThereAtTheNextStart() async throws {
        server.reply(manifest)
        let first = repository()
        await first.install(sources)
        let row = try #require(await first.homeRows().first)
        let titles = (1...120).map { #"{"id":"tt\#($0)","type":"movie","name":"T\#($0)"}"# }.joined(separator: ",")
        server.reply(#"{"metas":[\#(titles)]}"#)
        #expect(try await first.catalog(row).count == 120)
        try await Task.sleep(for: .milliseconds(200))

        #expect(await first.isFresh(row))
        let next = repository()
        let cached = await next.cachedCatalog(row)
        #expect(cached?.count == AddonDisk.catalogLimit)
        #expect(cached?.first?.id == "tt1")
        // A catalog from the disk is not fresh, so that Home asks the addon again.
        #expect(await !next.isFresh(row))
    }

    @Test func aDamagedFileGivesAnEmptyDisk() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: folder.appendingPathComponent("manifests.json"))
        #expect(AddonDisk(folder: folder).manifests.value.isEmpty)
    }
}
