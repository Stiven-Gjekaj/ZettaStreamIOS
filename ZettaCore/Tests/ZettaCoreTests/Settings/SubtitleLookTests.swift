import Testing
@testable import ZettaCore

struct SubtitleLookTests {
    @Test func theBackgroundOpacityGoesFromNoneToSolid() {
        #expect(SubtitleBackground.allCases.map(\.alpha) == [0, 64, 128, 191, 255])
    }

    @Test func eachChoiceHasTheNameOfTheAndroidApp() {
        #expect(SubtitleSize.allCases.map(\.rawValue) == ["Small", "Normal", "Large", "Huge"])
        #expect(SubtitleColor.allCases.map(\.rawValue) == ["White", "Yellow", "Gray", "Cyan"])
        #expect(SubtitleBackground.allCases.map(\.rawValue) == ["None", "Light", "Medium", "Dark", "Solid"])
        #expect(SubtitleFont.allCases.map(\.rawValue) == ["Default", "Sans", "Serif", "Mono", "Bold"])
        #expect(SubtitleEdge.allCases.map(\.rawValue) == ["None", "Outline", "Shadow", "Raised"])
        #expect(SideBars.allCases.map(\.rawValue) == ["Black", "Ambient", "Stretch"])
        #expect(VideoFilter.allCases.map(\.rawValue) == ["None", "Crt", "Vhs", "Vintage", "BlackWhite"])
    }

    @Test func theLabelsAreTheLabelsOfTheAndroidApp() {
        #expect(SubtitleColor.gray.label == "Light gray")
        #expect(SubtitleFont.mono.label == "Monospace")
        #expect(SubtitleEdge.shadow.label == "Drop shadow")
        #expect(SideBars.ambient.label == "Ambient blur")
        #expect(SubtitleBackground.medium.label == "50%")
        #expect(SubtitleColor.yellow.argb == 0xFFFF_E14D)
        #expect(SubtitleSize.large.scale == 1.3)
    }

    @Test func onlyTheColourFiltersChangeThePixels() {
        #expect(VideoFilter.allCases.filter(\.colour) == [.vhs, .vintage, .blackWhite])
        #expect(VideoFilter.allCases.filter(\.tube) == [.crt])
    }
}
