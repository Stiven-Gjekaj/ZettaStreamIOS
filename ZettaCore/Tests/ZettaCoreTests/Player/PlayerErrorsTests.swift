import Testing
@testable import ZettaCore

struct PlayerErrorsTests {
    @Test func aWebPageGetsItsOwnMessage() {
        #expect(PlayerErrors.describe(.notVideo).contains("web page"))
    }

    @Test func anUnknownFaultShowsItsName() {
        #expect(PlayerErrors.describe(.other(name: "ERROR_CODE_X")) == "This stream does not play (ERROR_CODE_X).")
    }

    @Test func damagedDataInTheMiddleGetsItsOwnMessage() {
        #expect(PlayerErrors.describeMidStream(.notVideo) == "The stream sent damaged video data.")
        #expect(PlayerErrors.describeMidStream(.refused) == PlayerErrors.describe(.refused))
    }

    @Test func aNetworkErrorReconnectsUpToTheLimit() {
        #expect(PlayerErrors.shouldRetry(.network, retries: 0))
        #expect(PlayerErrors.shouldRetry(.refused, retries: 2))
        #expect(!PlayerErrors.shouldRetry(.network, retries: PlayerErrors.maxRetries))
    }

    @Test func aFormatErrorDoesNotReconnect() {
        #expect(!PlayerErrors.shouldRetry(.notVideo, retries: 0))
        #expect(!PlayerErrors.shouldRetry(.decoder, retries: 0))
    }

    @Test func damagedDataReconnectsThenSkipsThenGoesToTheNextSource() {
        #expect(PlayerErrors.midStream(.notVideo, retries: 0, hasNextSource: true) == .reconnect)
        #expect(PlayerErrors.midStream(.notVideo, retries: 1, hasNextSource: true) == .skipAhead)
        #expect(PlayerErrors.midStream(.notVideo, retries: 2, hasNextSource: true) == .nextSource)
        #expect(PlayerErrors.midStream(.notVideo, retries: 2, hasNextSource: false) == .stop)
    }

    @Test func aNetworkErrorReconnectsThreeTimesAndADecoderErrorChangesTheSource() {
        #expect(PlayerErrors.midStream(.noConnection, retries: 2, hasNextSource: true) == .reconnect)
        #expect(PlayerErrors.midStream(.noConnection, retries: 3, hasNextSource: true) == .nextSource)
        #expect(PlayerErrors.midStream(.decoder, retries: 0, hasNextSource: true) == .nextSource)
        #expect(PlayerErrors.midStream(.decoder, retries: 0, hasNextSource: false) == .stop)
    }

    @Test func anOtherFaultReconnectsOneTimeOnly() {
        #expect(PlayerErrors.midStream(.other(name: "X"), retries: 0, hasNextSource: true) == .reconnect)
        #expect(PlayerErrors.midStream(.other(name: "X"), retries: 1, hasNextSource: true) == .nextSource)
    }

    @Test func aDirectLinkHasAStartLimitAndATorrentHasNone() {
        #expect(PlayerErrors.startLimitMs(isTorrent: false) == 45_000)
        #expect(PlayerErrors.startLimitMs(isTorrent: true) == nil)
    }

    @Test func anHlsStreamReconnectsSixTimesAndAFileThreeTimes() {
        #expect(PlayerErrors.midStream(.network, retries: 2, hasNextSource: true) == .reconnect)
        #expect(PlayerErrors.midStream(.network, retries: 3, hasNextSource: true) == .nextSource)
        #expect(PlayerErrors.midStream(.network, retries: 5, hasNextSource: true, isHls: true) == .reconnect)
        #expect(PlayerErrors.midStream(.network, retries: 6, hasNextSource: true, isHls: true) == .nextSource)
        #expect(PlayerErrors.midStream(.decoder, retries: 0, hasNextSource: false, isHls: true) == .stop)
    }

    @Test func afterTwoFaultsAnHlsStreamStepsDownInQuality() {
        #expect(PlayerErrors.hlsHeightLimit(retries: 1, playing: 1080, limit: nil) == nil)
        #expect(PlayerErrors.hlsHeightLimit(retries: 2, playing: 1080, limit: nil) == 720)
        #expect(PlayerErrors.hlsHeightLimit(retries: 3, playing: 720, limit: 720) == 480)
        #expect(PlayerErrors.hlsHeightLimit(retries: 2, playing: 2160, limit: nil) == 1440)
        // An odd height steps to the next lower one in the list.
        #expect(PlayerErrors.hlsHeightLimit(retries: 2, playing: 800, limit: nil) == 720)
        #expect(PlayerErrors.hlsHeightLimit(retries: 4, playing: 360, limit: 360) == 360)
        // With no known height, the first step is 720.
        #expect(PlayerErrors.hlsHeightLimit(retries: 2, playing: 0, limit: nil) == 720)
        #expect(PlayerErrors.hlsHeightLimit(retries: 1, playing: 0, limit: 480) == 480)
    }
}

