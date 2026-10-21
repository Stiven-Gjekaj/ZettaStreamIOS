import Foundation
import Testing
@testable import ZettaCore

struct StreamHealthTests {
    /// A clock that a test moves by hand.
    private final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Int64 = 0
        var now: Int64 {
            get { lock.withLock { value } }
            set { lock.withLock { value = newValue } }
        }
    }

    /// A file in a new folder, so that tests that run at the same time do not share it.
    private func newFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("health-\(UUID().uuidString)").appendingPathComponent("health.json")
    }

    @Test func aFailedStreamIsRememberedForADay() throws {
        let clock = TestClock()
        let health = StreamHealth(file: newFile(), clock: { clock.now })
        try health.failed(key: "a|https://x.test/1.m3u8", addonUrl: "a")
        #expect(health.failedRecently(key: "a|https://x.test/1.m3u8"))
        clock.now = StreamHealth.streamMemory
        #expect(!health.failedRecently(key: "a|https://x.test/1.m3u8"))
    }

    @Test func anAddonIsUnreliableAfterThreeFailuresAndAPlayClearsIt() throws {
        let health = StreamHealth(file: newFile())
        for i in 0..<3 { try health.failed(key: "a|\(i)", addonUrl: "a") }
        #expect(health.unreliable(addonUrl: "a"))
        try health.played(key: "a|9", addonUrl: "a")
        #expect(!health.unreliable(addonUrl: "a"))
    }

    @Test func twoFailuresDoNotMakeAnAddonUnreliable() throws {
        let health = StreamHealth(file: newFile())
        for i in 0..<2 { try health.failed(key: "a|\(i)", addonUrl: "a") }
        #expect(!health.unreliable(addonUrl: "a"))
    }

    @Test func theMarksStayAfterARestart() throws {
        let file = newFile()
        try StreamHealth(file: file).failed(key: "a|1", addonUrl: "a")
        #expect(StreamHealth(file: file).failedRecently(key: "a|1"))
    }

    @Test func aBrokenFileGivesNoMarks() throws {
        let file = newFile()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: file)
        #expect(!StreamHealth(file: file).failedRecently(key: "a|1"))
    }

    @Test func theKeyIsTheLinkOrTheTorrentAndItsFile() {
        #expect(StreamHealth.key(addonUrl: "a", url: "https://x.test/1", infoHash: nil, fileIdx: nil) == "a|https://x.test/1")
        #expect(StreamHealth.key(addonUrl: "a", url: "", infoHash: "ABC", fileIdx: 2) == "a|abc:2")
        #expect(StreamHealth.key(addonUrl: nil, url: nil, infoHash: nil, fileIdx: nil) == "|:-1")
    }

    @Test func theOrderUsesTheMarkOfAListedStream() throws {
        let health = StreamHealth(file: newFile())
        let addon = Addon(manifestUrl: "https://a.test/manifest.json", manifest: Manifest(id: "a", name: "A"))
        let listed = ListedStream(addon: addon, stream: AddonStream(url: "https://x.test/1.m3u8"))
        try health.failed(key: StreamHealth.key(listed), addonUrl: addon.manifestUrl)
        #expect(health.failedRecently(listed))
    }
}
