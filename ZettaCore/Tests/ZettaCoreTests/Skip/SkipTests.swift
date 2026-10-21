import Foundation
import Testing
@testable import ZettaCore

struct SkipTests {
    private let ranges = [
        SkipRange(kind: .opening, start: 60_000, end: 150_000),
        SkipRange(kind: .ending, start: 1_284_000, end: 1_377_000),
    ]

    @Test func insideARangeTheButtonGoesToItsEnd() {
        #expect(Skip.action(ranges, position: 90_000) == .seekTo(position: 150_000, kind: .opening))
        #expect(Skip.action(ranges, position: 1_300_000) == .seekTo(position: 1_377_000, kind: .ending))
    }

    @Test func aShortColdOpenStillSkipsTheOpening() {
        #expect(Skip.action(ranges, position: 5_000) == .seekTo(position: 150_000, kind: .opening))
    }

    @Test func anOpeningMoreThanThreeMinutesAheadIsNotSkipped() {
        let late = [SkipRange(kind: .opening, start: 300_000, end: 390_000)]
        #expect(Skip.action(late, position: 119_999) == .jump(by: Skip.fallback))
        #expect(Skip.action(late, position: 120_000) == .seekTo(position: 390_000, kind: .opening))
    }

    @Test func withNoRangeTheButtonJumps() {
        #expect(Skip.action(ranges, position: 600_000) == .jump(by: Skip.fallback))
        #expect(Skip.action([], position: 0) == .jump(by: Skip.fallback))
    }

    @Test func theCurrentRangeIsTheOneThatHoldsThePosition() {
        #expect(Skip.current(ranges, position: 61_000)?.kind == .opening)
        #expect(Skip.current(ranges, position: 150_000) == nil)
    }

    @Test func readsTheMalIdFromKitsuMappings() {
        let json = """
            {"data":[{"attributes":{"externalSite":"thetvdb/series","externalId":"79481"}},
            {"attributes":{"externalSite":"myanimelist/anime","externalId":"1535"}}]}
            """
        #expect(Skip.malIdFromKitsu(Data(json.utf8)) == 1535)
        #expect(Skip.malIdFromKitsu(Data(#"{"data":[]}"#.utf8)) == nil)
        #expect(Skip.malIdFromKitsu(Data("not json".utf8)) == nil)
    }

    @Test func readsAnAniSkipAnswer() {
        let json = """
            {"found":true,"results":[
            {"interval":{"startTime":1284,"endTime":1377},"skipType":"ed"},
            {"interval":{"startTime":1.039,"endTime":91.039},"skipType":"op"},
            {"interval":{"startTime":5,"endTime":5},"skipType":"recap"}]}
            """
        #expect(Skip.parseAniSkip(Data(json.utf8)) == [
            SkipRange(kind: .opening, start: 1_039, end: 91_039),
            SkipRange(kind: .ending, start: 1_284_000, end: 1_377_000),
        ])
        #expect(Skip.parseAniSkip(Data(#"{"found":false,"results":[]}"#.utf8)) == [])
        #expect(Skip.parseAniSkip(Data("not json".utf8)) == [])
    }

    @Test func thePlainOpeningWinsOverAMixedOne() {
        // The real answer for Attack on Titan episode 1.
        let json = """
            {"found":true,"results":[
            {"interval":{"startTime":128.406,"endTime":218.406},"skipType":"op"},
            {"interval":{"startTime":1342.795,"endTime":1430.616},"skipType":"ed"},
            {"interval":{"startTime":75,"endTime":135},"skipType":"mixed-op"},
            {"interval":{"startTime":1351.63,"endTime":1441.63},"skipType":"mixed-ed"}]}
            """
        let ranges = Skip.parseAniSkip(Data(json.utf8))
        #expect(ranges.map(\.kind) == [.opening, .ending])
        #expect(Skip.action(ranges, position: 10_000) == .seekTo(position: 218_406, kind: .opening))
    }

    @Test func aMixedOpeningCountsWhenItIsTheOnlyOne() {
        let json = #"{"found":true,"results":[{"interval":{"startTime":75,"endTime":135},"skipType":"mixed-op"}]}"#
        #expect(Skip.parseAniSkip(Data(json.utf8)) == [SkipRange(kind: .opening, start: 75_000, end: 135_000)])
    }

    @Test func readsTheKitsuEpisodeFromAVideoId() {
        let parsed = Skip.kitsuEpisode("kitsu:1376:5")
        #expect(parsed?.kitsu == 1376)
        #expect(parsed?.episode == 5)
        #expect(Skip.kitsuEpisode("tt0903747:1:2") == nil)
        #expect(Skip.kitsuEpisode("kitsu:1376") == nil)
    }

    @Test func theCountdownStartsAtTheEndingOrTwentySecondsBeforeTheEnd() {
        #expect(Skip.countdownStart(ranges, duration: 1_400_000) == 1_284_000)
        #expect(Skip.countdownStart([], duration: 600_000) == 580_000)
        #expect(Skip.countdownStart([], duration: 5_000) == 0)
        #expect(Skip.countdownStart(ranges, duration: 0) == nil)
    }

    @Test func theNextEpisodeIsPreparedOneMinuteBeforeTheCountdown() {
        #expect(!Skip.shouldPrepareNext([], duration: 600_000, position: 519_999))
        #expect(Skip.shouldPrepareNext([], duration: 600_000, position: 520_000))
        #expect(!Skip.shouldPrepareNext([], duration: 0, position: 520_000))
    }

    @Test func autoSkipJumpsOverTheOpeningOneTimeOnly() {
        #expect(Skip.autoSkip(ranges, position: 70_000, done: [])?.kind == .opening)
        #expect(Skip.autoSkip(ranges, position: 70_000, done: [60_000]) == nil)
        #expect(Skip.autoSkip(ranges, position: 1_300_000, done: []) == nil)
    }
}
