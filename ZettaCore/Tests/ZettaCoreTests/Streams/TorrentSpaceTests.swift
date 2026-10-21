import Foundation
import Testing
@testable import ZettaCore

struct TorrentSpaceTests {
    @Test func aTorrentStartsWithOneGigabyteAndStopsBelowThreeHundredMegabytes() {
        #expect(TorrentSpace.canStart(free: 1 << 30))
        #expect(!TorrentSpace.canStart(free: (1 << 30) - 1))
        #expect(TorrentSpace.canContinue(free: 300 << 20))
        #expect(!TorrentSpace.canContinue(free: (300 << 20) - 1))
    }

    @Test func anUnknownFreeSpaceDoesNotStopATorrent() {
        #expect(TorrentSpace.canStart(free: nil))
        #expect(TorrentSpace.canContinue(free: nil))
    }

    @Test func theFreeSpaceOfTheTemporaryFolderIsKnown() {
        let free = TorrentSpace.free(at: FileManager.default.temporaryDirectory)
        #expect((free ?? 0) > 0)
    }
}
