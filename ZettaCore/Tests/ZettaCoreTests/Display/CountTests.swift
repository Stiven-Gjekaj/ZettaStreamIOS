import Testing
@testable import ZettaCore

struct CountTests {
    @Test func oneHasNoPluralEnding() {
        #expect(Display.count(1, "stream") == "1 stream")
        #expect(Display.count(0, "stream") == "0 streams")
        #expect(Display.count(3, "torrent stream") == "3 torrent streams")
    }
}
