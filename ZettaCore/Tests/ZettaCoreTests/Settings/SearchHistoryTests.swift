import Testing
@testable import ZettaCore

struct SearchHistoryTests {
    @Test func aNewSearchGoesToTheTopAndARepeatMoves() {
        var h = SearchHistory.add([], " frieren ")
        h = SearchHistory.add(h, "dragon")
        h = SearchHistory.add(h, "Frieren")
        #expect(h == ["Frieren", "dragon"])
        #expect(SearchHistory.add(h, "   ") == h)
    }

    @Test func theHistoryKeepsOnlyTheNewest() {
        let h = (1...12).reduce([String]()) { SearchHistory.add($0, "q\($1)") }
        #expect(h.count == SearchHistory.max)
        #expect(h.first == "q12")
        #expect(h.last == "q5")
    }
}
