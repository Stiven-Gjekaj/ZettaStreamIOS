import Testing
@testable import ZettaCore

struct VideoFiltersTests {
    private func of(_ filter: VideoFilter, _ r: Float, _ g: Float, _ b: Float) -> [Float] {
        ColourMatrix.of(filter)!.apply(r, g, b)
    }

    private func near(_ a: Float, _ b: Float) -> Bool { abs(a - b) < 0.0001 }

    @Test func onlyTheColourFiltersHaveAMatrix() {
        #expect(ColourMatrix.of(.none) == nil)
        #expect(ColourMatrix.of(.crt) == nil)
        for filter in VideoFilter.allCases where filter.colour {
            #expect(ColourMatrix.of(filter) != nil, "\(filter)")
        }
    }

    @Test func blackAndWhiteHasNoColour() {
        let red = of(.blackWhite, 1, 0, 0)
        #expect(near(red[0], red[1]))
        #expect(near(red[1], red[2]))
        let white = of(.blackWhite, 1, 1, 1)
        #expect(white.allSatisfy { near($0, 1) })
    }

    @Test func blackAndWhiteKeepsTheNumbersOfRec601() throws {
        let row = try #require(ColourMatrix.of(.blackWhite)).rows[0]
        #expect(near(row[0], 0.299 * 1.08))
        #expect(near(row[1], 0.587 * 1.08))
        #expect(near(row[2], 0.114 * 1.08))
        #expect(near(row[3], -0.04))
    }

    @Test func vintageIsWarmAndFaded() {
        let grey = of(.vintage, 0.5, 0.5, 0.5)
        #expect(grey[0] > grey[2] + 0.05, "red over blue")
        let black = of(.vintage, 0, 0, 0)
        #expect(black.allSatisfy { $0 > 0.03 }, "black is lifted")
        let white = of(.vintage, 1, 1, 1)
        #expect(white[2] < 1, "white is not full")
    }

    @Test func vhsHasLessColourAndAWarmTint() {
        let red = of(.vhs, 1, 0, 0)
        #expect(red[1] > 0.05, "red spills into green")
        let grey = of(.vhs, 0.5, 0.5, 0.5)
        #expect(grey[0] > grey[2], "warm")
    }

    @Test func theGlMatrixIsInColumnOrderWithTheAddedValueLast() {
        let m = ColourMatrix([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]])
        let gl = m.columnMajor4x4
        #expect(gl[4] == 2)
        #expect(gl[12] == 4)
        #expect(gl[13] == 8)
        #expect(gl[15] == 1)
        #expect(gl[3] == 0)
    }

    @Test func theCoreImageVectorsHoldTheRowsAndTheAddedValues() {
        let m = ColourMatrix([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]])
        #expect(m.coreImageVectors == [[1, 2, 3, 0], [5, 6, 7, 0], [9, 10, 11, 0], [0, 0, 0, 1], [4, 8, 12, 0]])
    }

    @Test func theOverlaysMatchTheFilters() {
        #expect(VideoFilter.crt.tube)
        #expect(!VideoFilter.vhs.tube)
        #expect(VideoFilter.crt.scanlines == 0.5)
        #expect(VideoFilter.none.vignette == 0 && VideoFilter.none.grain == 0 && VideoFilter.none.scanlines == 0)
        #expect(VideoFilter(rawValue: "BlackWhite") == .blackWhite)
    }

    @Test func aScanlineIsAtLeastThreePointsApart() {
        #expect(FilterOverlay.scanlineStep(height: 2160) == 8)
        #expect(FilterOverlay.scanlineStep(height: 390) == 3)
    }
}
