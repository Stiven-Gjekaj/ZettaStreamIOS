import Testing
@testable import ZettaCore

struct ResumeTests {
    @Test func aPositionInsideTheVideoFits() {
        #expect(Resume.fits(position: 600_000, duration: 5_796_000))
    }

    @Test func aPositionPastTheEndOfAShorterSourceDoesNotFit() {
        #expect(!Resume.fits(position: 982_890, duration: 634_584))
        #expect(!Resume.fits(position: 630_000, duration: 634_584))
    }

    @Test func anUnknownDurationAlwaysFits() {
        #expect(Resume.fits(position: 982_890, duration: 0))
    }
}
