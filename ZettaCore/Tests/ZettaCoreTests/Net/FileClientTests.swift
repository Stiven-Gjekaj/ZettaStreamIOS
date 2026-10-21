import Foundation
import Testing
@testable import ZettaCore

struct FileClientTests {
    private let server = StubServer()
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("files-\(UUID().uuidString)")
    private var client: FileClient { FileClient(session: server.session, userAgent: "ZettaStream/test", folder: folder) }

    private func client(at time: TimeInterval) -> FileClient {
        FileClient(session: server.session, userAgent: "ZettaStream/test", folder: folder, clock: { Date(timeIntervalSince1970: time) })
    }

    @Test func aGzipFileIsOpenedAlsoWithNoGzName() async throws {
        // The output of `printf '#EXTM3U\n' | gzip -n`.
        server.reply(data: Data([
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x53, 0x76,
            0x8d, 0x08, 0xf1, 0x35, 0x0e, 0xe5, 0x02, 0x00, 0xb5, 0x98, 0xec, 0x41,
            0x08, 0x00, 0x00, 0x00,
        ]))
        let data = try await client.data(server.url("/list.m3u"))
        #expect(String(decoding: data, as: UTF8.self) == "#EXTM3U\n")
        #expect(server.lastRequest?.value(forHTTPHeaderField: "User-Agent") == "ZettaStream/test")
    }

    @Test func aPlainFileComesAsItIs() async throws {
        server.reply("<tv></tv>")
        #expect(try await client.data(server.url("/guide.xml")) == Data("<tv></tv>".utf8))
    }

    @Test func anErrorStatusThrows() async {
        server.reply("gone", status: 404)
        await #expect(throws: HTTPError(status: 404, url: server.url("/list.m3u"))) {
            try await client.data(server.url("/list.m3u"))
        }
    }

    @Test func aFileIsUsedAgainUntilItsKeepTimeEnds() async throws {
        let url = server.url("/list.m3u")
        server.reply("one")
        server.reply("two")
        #expect(try await client(at: 1_000).data(url, keepFor: 60) == Data("one".utf8))
        #expect(try await client(at: 1_059).data(url, keepFor: 60) == Data("one".utf8))
        #expect(server.paths.count == 1)
        #expect(try await client(at: 1_060).data(url, keepFor: 60) == Data("two".utf8))
        #expect(server.paths.count == 2)
    }

    @Test func noKeepTimeAlwaysDownloads() async throws {
        let url = server.url("/list.m3u")
        server.reply("one")
        server.reply("two")
        #expect(try await client(at: 1_000).data(url, keepFor: 60) == Data("one".utf8))
        #expect(try await client(at: 1_001).data(url) == Data("two".utf8))
    }

    @Test func aFailedDownloadKeepsTheEarlierFile() async throws {
        let url = server.url("/list.m3u")
        server.reply("one")
        server.reply("gone", status: 503)
        _ = try await client(at: 1_000).data(url)
        await #expect(throws: HTTPError(status: 503, url: url)) { try await client(at: 2_000).data(url) }
        #expect(try await client(at: 1_010).data(url, keepFor: 60) == Data("one".utf8))
    }

    @Test func twoUrlsHaveTwoFiles() async throws {
        server.reply("a")
        server.reply("b")
        #expect(try await client(at: 0).data(server.url("/a"), keepFor: 60) == Data("a".utf8))
        #expect(try await client(at: 0).data(server.url("/b"), keepFor: 60) == Data("b".utf8))
        #expect(FileClient.name(server.url("/a")).count == 64)
    }
}
