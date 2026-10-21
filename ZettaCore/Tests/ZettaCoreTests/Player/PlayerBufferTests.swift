import Testing
@testable import ZettaCore

struct PlayerBufferTests {
    @Test func aTorrentKeepsMoreVideoReady() {
        let link = PlayerBuffer.of(isTorrent: false)
        let torrent = PlayerBuffer.of(isTorrent: true)
        #expect(link == PlayerBuffer(minMs: 30_000, maxMs: 90_000, forPlaybackMs: 2_500, afterStallMs: 12_000))
        #expect(torrent == PlayerBuffer(minMs: 30_000, maxMs: 120_000, forPlaybackMs: 6_000, afterStallMs: 20_000))
    }

    @Test func theCachingOfVLCIsBetweenTheTwoWaits() {
        let buffer = PlayerBuffer(minMs: 30_000, maxMs: 90_000, forPlaybackMs: 3_000, afterStallMs: 15_000)
        #expect(buffer.networkCachingMs == 6_000)
        for buffer in [PlayerBuffer.of(isTorrent: false), PlayerBuffer.of(isTorrent: true)] {
            #expect(buffer.networkCachingMs > buffer.forPlaybackMs)
            #expect(buffer.networkCachingMs <= buffer.afterStallMs)
        }
    }
}
