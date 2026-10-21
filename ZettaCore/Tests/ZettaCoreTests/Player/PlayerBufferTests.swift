import Testing
@testable import ZettaCore

struct PlayerBufferTests {
    @Test func aTorrentKeepsMoreVideoReady() {
        let link = PlayerBuffer.of(isTorrent: false)
        let torrent = PlayerBuffer.of(isTorrent: true)
        #expect(link == PlayerBuffer(minMs: 30_000, maxMs: 90_000, forPlaybackMs: 2_500, afterStallMs: 12_000))
        #expect(torrent == PlayerBuffer(minMs: 30_000, maxMs: 120_000, forPlaybackMs: 6_000, afterStallMs: 20_000))
    }
}
