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
}
