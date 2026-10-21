import Testing
@testable import ZettaCore

struct GuideLayoutTests {
    private let hour: Int64 = 60 * 60_000
    private func p(_ title: String, _ start: Int64, _ stop: Int64) -> Programme {
        Programme(channelId: "ch", title: title, start: start, stop: stop)
    }

    @Test func theWindowStartsAtTheLastHalfHour() {
        #expect(GuideLayout.windowStart(10 * hour + 47 * 60_000) == 10 * hour + 30 * 60_000)
    }

    @Test func programmesAreCutAtTheEdgesOfTheWindow() throws {
        let blocks = GuideLayout.blocks(
            [p("late", 14 * hour, 15 * hour), p("news", 9 * hour, 11 * hour), p("film", 11 * hour, 14 * hour), p("old", 8 * hour, 9 * hour)],
            from: 10 * hour
        )
        #expect(blocks.map(\.programme.title) == ["news", "film"])
        try #require(blocks.count == 2)
        #expect(abs(blocks[0].offset - 0) < 0.0001)
        #expect(abs(blocks[0].width - 1.0 / 3) < 0.0001)
        #expect(abs(blocks[1].offset - 1.0 / 3) < 0.0001)
        #expect(abs(blocks[1].width - 2.0 / 3) < 0.0001)
    }

    // This test is not in the Android app. It holds an edge case of the Kotlin code.
    @Test func aProgrammeWithNoLengthIsLeftOut() {
        #expect(GuideLayout.blocks([p("empty", 11 * hour, 11 * hour), p("back", 12 * hour, 11 * hour)], from: 10 * hour) == [])
    }
}
