import Testing
@testable import ZettaCore

struct TypeKeyTests {
    @Test func typesThatMeanTheSameThingHaveOneKey() {
        #expect(Set(["sport", "sports", "Sports", "events"].map(Display.typeKey)) == ["sport"])
        #expect(Set(["tv", "channel", "channels"].map(Display.typeKey)) == ["tv"])
        #expect(Display.typeKey("anime") == "anime")
    }

    @Test func eachKeyHasOneLabel() {
        #expect(Display.typeLabel("sports") == "Sports")
        #expect(Display.typeLabel("sport") == "Sports")
        #expect(Display.typeLabel("channel") == "TV channels")
        #expect(Display.typeLabel(nil) == "All")
        #expect(Display.typeLabel("radio") == "Radio")
    }
}
