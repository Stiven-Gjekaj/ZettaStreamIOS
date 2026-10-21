import Testing
@testable import ZettaCore

struct SeasonSuffixTests {
    @Test func removesTheSeasonFromTheEndOfAName() {
        #expect(Display.withoutSeasonSuffix("My Hero Academia Season 2") == "My Hero Academia")
        #expect(Display.withoutSeasonSuffix("Re:Zero kara Hajimeru Isekai Seikatsu 4th Season") == "Re:Zero kara Hajimeru Isekai Seikatsu")
        #expect(Display.withoutSeasonSuffix("Spy x Family Part 2") == "Spy x Family")
        #expect(Display.withoutSeasonSuffix("Attack on Titan") == "Attack on Titan")
        #expect(Display.withoutSeasonSuffix("Mob Psycho 100") == "Mob Psycho 100")
        #expect(Display.withoutSeasonSuffix("Show: season 3") == "Show")
    }
}
