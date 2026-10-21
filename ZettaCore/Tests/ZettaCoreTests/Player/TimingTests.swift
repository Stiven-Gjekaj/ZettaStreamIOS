import Testing
@testable import ZettaCore

struct TimingTests {
    @Test func aStepStaysInsideTheLimit() {
        #expect(Timing.step(0, direction: 1, step: Timing.subtitleStep, limit: Timing.subtitleLimit) == 250)
        #expect(Timing.step(0, direction: -1, step: Timing.subtitleStep, limit: Timing.subtitleLimit) == -250)
        #expect(Timing.step(1_980, direction: 1, step: Timing.audioStep, limit: Timing.audioLimit) == 2_000)
        #expect(Timing.step(-2_000, direction: -1, step: Timing.audioStep, limit: Timing.audioLimit) == -2_000)
    }

    @Test func theLabelShowsTheSignAndTheSeconds() {
        #expect(Timing.label(0) == "None")
        #expect(Timing.label(250) == "+0.25 s")
        #expect(Timing.label(-1_500) == "-1.5 s")
        #expect(Timing.label(2_000) == "+2 s")
        #expect(Timing.label(50) == "+0.05 s")
        #expect(Timing.label(-30_000) == "-30 s")
        #expect(Timing.label(1_255) == "+1.26 s")
        #expect(Timing.label(3) == "+0 s")
    }

    @Test func theTimeShowsHoursOnlyWhenItHasThem() {
        #expect(Timing.formatTime(245_000) == "4:05")
        #expect(Timing.formatTime(3_723_999) == "1:02:03")
        #expect(Timing.formatTime(0) == "0:00")
        #expect(Timing.formatTime(-1) == "--:--")
    }
}
