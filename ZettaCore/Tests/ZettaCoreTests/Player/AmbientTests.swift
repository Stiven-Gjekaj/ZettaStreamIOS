import Testing
@testable import ZettaCore

struct AmbientTests {
    @Test func onlyAVideoOfAnotherShapeNeedsTheFill() {
        #expect(Ambient.needed(videoWidth: 640, videoHeight: 480, pixelRatio: 1, screenWidth: 1920, screenHeight: 1080))
        #expect(Ambient.needed(videoWidth: 1920, videoHeight: 800, pixelRatio: 1, screenWidth: 1920, screenHeight: 1080))
        #expect(!Ambient.needed(videoWidth: 1920, videoHeight: 1080, pixelRatio: 1, screenWidth: 1920, screenHeight: 1080))
        #expect(!Ambient.needed(videoWidth: 1280, videoHeight: 720, pixelRatio: 1, screenWidth: 3840, screenHeight: 2160))
        // A DVD picture of 720 x 480 with wide pixels is 16:9 on the screen.
        #expect(!Ambient.needed(videoWidth: 720, videoHeight: 480, pixelRatio: 32 / 27, screenWidth: 1920, screenHeight: 1080))
        #expect(!Ambient.needed(videoWidth: 0, videoHeight: 0, pixelRatio: 1, screenWidth: 1920, screenHeight: 1080))
    }

    @Test func theBlurSpreadsAPointAndKeepsAFlatColour() {
        let flat = [UInt32](repeating: 0xFF33_6699, count: 16)
        #expect(Ambient.blur(flat, width: 4, height: 4, radius: 1) == flat)
        var point = [UInt32](repeating: 0xFF00_0000, count: 25)
        point[12] = 0xFFFF_FFFF
        let out = Ambient.blur(point, width: 5, height: 5, radius: 1)
        #expect((1...254).contains(out[12] & 0xFF))
        #expect(out[11] & 0xFF > 0)
        #expect(out[0] >> 24 == 0xFF)
    }

    @Test func theChangeIsTheAverageDifferenceOfTheColours() {
        let a = [UInt32](repeating: 0xFF10_2030, count: 4)
        #expect(Ambient.change(a, a) == 0)
        #expect(Ambient.change(a, [UInt32](repeating: 0xFF1A_2A3A, count: 4)) == 10)
        #expect(Ambient.change(a, [0, 0]) == Int.max)
    }
}
