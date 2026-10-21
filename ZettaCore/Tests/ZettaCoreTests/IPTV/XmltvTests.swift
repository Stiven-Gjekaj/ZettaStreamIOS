import Foundation
import Testing
@testable import ZettaCore

struct XmltvTests {
    private func ms(_ text: String) -> Int64 {
        Int64(ISO8601DateFormatter().date(from: text)!.timeIntervalSince1970 * 1_000)
    }

    private let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="news.test"><display-name>News</display-name></channel>
          <programme start="20261008100000 +0000" stop="20261008110000 +0000" channel="news.test">
            <title lang="en">Morning</title><desc>The news.</desc>
          </programme>
          <programme start="20261008130000 +0200" stop="20261008120000 +0000" channel="news.test">
            <title>Noon</title>
          </programme>
          <programme start="20261008100000 +0000" stop="20261008110000 +0000" channel="other.test">
            <title>Other</title>
          </programme>
          <programme start="20261001100000 +0000" stop="20261001110000 +0000" channel="news.test">
            <title>Old</title>
          </programme>
        </tv>
        """

    private func guide() throws -> Guide {
        try Xmltv.parse(Data(xml.utf8), channelIds: ["news.test"], from: ms("2026-10-08T00:00:00Z"), to: ms("2026-10-09T00:00:00Z"))
    }

    @Test func keepsOnlyTheChosenChannelsAndTheTimeWindow() throws {
        let guide = try guide()
        #expect(guide.programmes("news.test").map(\.title) == ["Morning", "Noon"])
        #expect(guide.programmes("other.test") == [])
        #expect(guide.programmes("news.test").first?.description == "The news.")
    }

    @Test func readsTheTimeZoneOffset() throws {
        #expect(try guide().programmes("news.test")[1].start == ms("2026-10-08T11:00:00Z"))
        #expect(Xmltv.parseTime("20261008120000") == ms("2026-10-08T12:00:00Z"))
        #expect(Xmltv.parseTime("bad") == 0)
    }

    @Test func nowAndNextFindsTheCurrentAndTheNextProgramme() throws {
        let guide = try guide()
        let current = guide.nowAndNext("news.test", now: ms("2026-10-08T10:30:00Z"))
        #expect(current.now?.title == "Morning")
        #expect(current.next?.title == "Noon")
        let early = guide.nowAndNext("news.test", now: ms("2026-10-08T09:00:00Z"))
        #expect(early.now == nil)
        #expect(early.next?.title == "Morning")
    }

    @Test func aChannelMatchesInAnotherForm() throws {
        let text = #"<tv><programme start="20261008100000 +0000" stop="20261008110000 +0000" channel="News.24.al"><title>Lajme</title></programme></tv>"#
        let guide = try Xmltv.parse(Data(text.utf8), channelIds: ["News24.al@SD"], from: ms("2026-10-08T00:00:00Z"), to: ms("2026-10-09T00:00:00Z"))
        #expect(guide.programmes("News24.al@SD").map(\.title) == ["Lajme"])
        #expect(Xmltv.channelKey("News.24.al") == "news24al")
    }

    @Test func twoFeedsOfOneChannelDoNotMix() throws {
        let text = """
            <tv>
              <programme start="20261008100000 +0000" stop="20261008110000 +0000" channel="CNN.us@East"><title>East</title></programme>
              <programme start="20261008100000 +0000" stop="20261008110000 +0000" channel="CNN.us@West"><title>West</title></programme>
            </tv>
            """
        let guide = try Xmltv.parse(Data(text.utf8), channelIds: nil, from: ms("2026-10-08T00:00:00Z"), to: ms("2026-10-09T00:00:00Z"))
        #expect(guide.programmes("CNN.us@East").map(\.title) == ["East"])
        #expect(guide.programmes("cnn.us@WEST").map(\.title) == ["West"])
        #expect(guide.programmes("CNN.us").map(\.title) == ["East"])
        #expect(guide.programmes("BBC.uk") == [])
    }

    // The tests below are not in the Android app. They hold the edge cases of the Kotlin code.

    @Test func readsEachFormOfTheOffset() {
        let noon = ms("2026-10-08T12:00:00Z")
        #expect(Xmltv.parseTime("20261008140000 +02:00") == noon)
        #expect(Xmltv.parseTime("20261008140000+02") == noon)
        #expect(Xmltv.parseTime("20261008100000 -0200") == noon)
        #expect(Xmltv.parseTime("20261008120000 Z") == noon)
        #expect(Xmltv.parseTime("20261008120000 GMT") == 0)
        #expect(Xmltv.parseTime("20261008120000 +1900") == 0)
        #expect(Xmltv.parseTime("20261308120000") == 0)
        #expect(Xmltv.parseTime(nil) == 0)
    }

    @Test func aDayAfterTheEndOfTheMonthBecomesTheLastDay() {
        #expect(Xmltv.parseTime("20260231120000") == ms("2026-02-28T12:00:00Z"))
        #expect(Xmltv.parseTime("20261008240000") == ms("2026-10-09T00:00:00Z"))
    }

    @Test func twoGuidesJoinInTheOrderOfTheStartTimes() throws {
        let from = ms("2026-10-08T00:00:00Z"), to = ms("2026-10-09T00:00:00Z")
        let late = #"<tv><programme start="20261008120000" stop="20261008130000" channel="a"><title>Late</title></programme></tv>"#
        let early = #"<tv><programme start="20261008100000" stop="20261008110000" channel="a"><title>Early</title></programme></tv>"#
        let guide = try Xmltv.parse(Data(late.utf8), channelIds: nil, from: from, to: to)
            + Xmltv.parse(Data(early.utf8), channelIds: nil, from: from, to: to)
        #expect(guide.programmes("a").map(\.title) == ["Early", "Late"])
        #expect(Guide.empty.programmes("a") == [])
        #expect(guide.nowAndNext("a", now: ms("2026-10-08T14:00:00Z")).now == nil)
    }

    @Test func badXmlThrows() {
        #expect(throws: (any Error).self) {
            try Xmltv.parse(Data("<tv><programme".utf8), channelIds: nil, from: 0, to: 1)
        }
    }
}
