import Foundation
import Testing
@testable import ZettaCore

struct FileClientTests {
    private let server = StubServer()
    private var client: FileClient { FileClient(session: server.session, userAgent: "ZettaStream/test") }

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
}
