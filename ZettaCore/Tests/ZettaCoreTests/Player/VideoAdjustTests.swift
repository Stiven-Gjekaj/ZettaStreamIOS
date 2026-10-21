import Testing
@testable import ZettaCore

struct VideoAdjustTests {
    private func near(_ a: Float, _ b: Float, _ tolerance: Float = 0.01) -> Bool { abs(a - b) <= tolerance }

    @Test func noChangeGivesTheDefaults() {
        let adjust = VideoAdjust.of(ColourMatrix.identity)
        #expect(near(adjust.contrast, 1))
        #expect(near(adjust.brightness, 1))
        #expect(near(adjust.saturation, 1))
        #expect(near(adjust.hue, 0, 0.5))
        #expect(adjust.tint == nil)
        #expect(VideoAdjust.of(.none) == nil)
        #expect(VideoAdjust.of(.crt) == nil)
    }

    @Test func blackAndWhiteHasNoColourAndMoreContrast() throws {
        let adjust = try #require(VideoAdjust.of(.blackWhite))
        #expect(adjust.saturation < 0.01)
        #expect(near(adjust.contrast, 1.08))
        #expect(near(adjust.brightness, 1))
        #expect(adjust.tint == nil)
    }

    @Test func aSaturationMatrixGivesItsValue() {
        #expect(near(VideoAdjust.of(.saturation(0.5)).saturation, 0.5))
        #expect(near(VideoAdjust.of(.contrast(0.8)).contrast, 0.8))
        // A lift of 0.1 makes black 0.1 and keeps white: less contrast, and a little more light at the middle.
        let fade = VideoAdjust.of(.fade(lift: 0.1, top: 1))
        #expect(near(fade.contrast, 0.9))
        #expect(near(fade.brightness, 1.05))
    }

    @Test func vhsAndVintageAreWarm() throws {
        let vhs = try #require(VideoAdjust.of(.vhs))
        let vhsTint = try #require(vhs.tint)
        #expect(vhsTint[0] >= vhsTint[1] && vhsTint[1] > vhsTint[2])
        #expect(vhs.saturation > 0.5 && vhs.saturation < 0.85)
        let vintage = try #require(VideoAdjust.of(.vintage))
        let vintageTint = try #require(vintage.tint)
        #expect(vintageTint[0] >= vintageTint[1] && vintageTint[1] > vintageTint[2])
        #expect(vintage.saturation < vhs.saturation)
    }

    @Test func theGreysMatchTheMatrix() throws {
        for filter in VideoFilter.allCases {
            guard let matrix = ColourMatrix.of(filter), let adjust = VideoAdjust.of(filter) else { continue }
            for g: Float in [0.1, 0.5, 0.9] {
                let want = VideoAdjust.luma(matrix.apply(g, g, g))
                #expect(near(adjust.grey(g), want, 0.02), "\(filter) at \(g)")
            }
        }
    }
}
