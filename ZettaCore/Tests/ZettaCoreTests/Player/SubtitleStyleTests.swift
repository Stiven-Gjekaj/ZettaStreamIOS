import Testing
@testable import ZettaCore

struct SubtitleStyleTests {
    @Test func eachSizeStepIsAMultipleOfTheNormalSize() {
        #expect(SubtitleStyle.Size.allCases.map(\.scale) == [0.8, 1, 1.3, 1.6])
        #expect(SubtitleStyle.textFraction(.normal) == SubtitleStyle.normalTextFraction)
        #expect(SubtitleStyle.textFraction(.huge) == SubtitleStyle.normalTextFraction * 1.6)
    }

    @Test func aSavedSizeReadsTheNameOfTheAndroidApp() {
        #expect(SubtitleStyle.Size(rawValue: "Large") == .large)
        #expect(SubtitleStyle.Size(rawValue: "large") == nil)
    }

    @Test func theBackgroundIsBlackWithTheOpacityOfTheViewer() {
        #expect(SubtitleStyle.backgroundArgb(alpha: 0) == 0)
        #expect(SubtitleStyle.backgroundArgb(alpha: 128) == 0x8000_0000)
        #expect(SubtitleStyle.backgroundArgb(alpha: 300) == 0xFF00_0000)
    }
}
