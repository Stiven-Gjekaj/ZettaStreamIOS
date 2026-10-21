import Foundation
import Testing
@testable import ZettaCore

struct UpdateCheckerTests {
    private let server = StubServer()
    private var checker: UpdateChecker {
        UpdateChecker(session: server.session, userAgent: "ZettaStream/test", apiUrl: server.url("/repos/x/releases/latest"))
    }

    @Test func readsTheVersionAndThePageOfTheNewestRelease() async throws {
        server.reply(#"{"tag_name":"v0.3.1","html_url":"https://github.com/Stiven-Gjekaj/ZettaStreamIOS/releases/tag/v0.3.1"}"#)
        let release = try #require(await checker.latest())
        #expect(release == Release(version: "0.3.1", pageUrl: "https://github.com/Stiven-Gjekaj/ZettaStreamIOS/releases/tag/v0.3.1"))
        #expect(server.paths == ["/repos/x/releases/latest"])
        #expect(server.lastRequest?.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(server.lastRequest?.value(forHTTPHeaderField: "User-Agent") == "ZettaStream/test")
    }

    @Test func withNoPageTheLinkGoesToTheLatestRelease() async throws {
        server.reply(#"{"tag_name":"0.3.1"}"#)
        let release = try #require(await checker.latest())
        #expect(release.version == "0.3.1")
        #expect(release.pageUrl == UpdateChecker.latestPage)
    }

    @Test func theDefaultAsksTheRepositoryOfTheIosApp() {
        #expect(UpdateChecker.latestApi.hasSuffix("/repos/Stiven-Gjekaj/ZettaStreamIOS/releases/latest"))
    }

    @Test func anUpdateIsOnlyANewerVersion() async {
        server.reply(#"{"tag_name":"v0.3.1"}"#)
        #expect(await checker.update(from: "0.3.0")?.version == "0.3.1")
        server.reply(#"{"tag_name":"v0.3.1"}"#)
        #expect(await checker.update(from: "0.3.1") == nil)
    }

    @Test func aFaultGivesNoRelease() async {
        server.reply("{}", status: 404)
        #expect(await checker.latest() == nil)
        server.reply("not json")
        #expect(await checker.latest() == nil)
        // The server has no answer, so the connection fails.
        #expect(await checker.latest() == nil)
    }
}
