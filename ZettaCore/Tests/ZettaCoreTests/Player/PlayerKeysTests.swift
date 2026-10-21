import Testing
@testable import ZettaCore

struct PlayerKeysTests {
    @Test func theArrowsSpaceReturnAndEscapeAreTheKeysOfARemote() {
        #expect(PlayerKeys.keyboard(0x50) == .left)
        #expect(PlayerKeys.keyboard(0x4F) == .right)
        #expect(PlayerKeys.keyboard(0x52) == .up)
        #expect(PlayerKeys.keyboard(0x51) == .down)
        #expect(PlayerKeys.keyboard(0x2C) == .playPause)
        #expect(PlayerKeys.keyboard(0x28) == .select)
        #expect(PlayerKeys.keyboard(0x58) == .select)
        #expect(PlayerKeys.keyboard(0x29) == .back)
        #expect(PlayerKeys.keyboard(0x2B) == .options)
    }

    @Test func theLettersOfTheVideoSitesWork() {
        #expect(PlayerKeys.keyboard(0x0E) == .playPause)
        #expect(PlayerKeys.keyboard(0x0D) == .left)
        #expect(PlayerKeys.keyboard(0x0F) == .right)
        #expect(PlayerKeys.keyboard(0x06) == .subtitles)
        #expect(PlayerKeys.keyboard(0x04) == .audio)
        #expect(PlayerKeys.keyboard(0x16) == .skip)
        #expect(PlayerKeys.keyboard(0x11) == .next)
        #expect(PlayerKeys.keyboard(0x13) == .previous)
        #expect(PlayerKeys.keyboard(0x0C) == .info)
    }

    @Test func bothRowsOfNumbersGiveOneToNineAndZeroIsNothing() {
        #expect((0x1E...0x26).map(PlayerKeys.keyboard) == (1...9).map { .number($0) })
        #expect((0x59...0x61).map(PlayerKeys.keyboard) == (1...9).map { .number($0) })
        #expect(PlayerKeys.keyboard(0x27) == nil)
        #expect(PlayerKeys.keyboard(0x62) == nil)
        #expect(PlayerKeys.keyboard(0x05) == nil)
    }

    @Test func aControllerHasTheButtonsOfTheAndroidApp() {
        #expect(PlayerKeys.controller(.a) == .select)
        #expect(PlayerKeys.controller(.b) == .back)
        #expect(PlayerKeys.controller(.x) == .options)
        #expect(PlayerKeys.controller(.menu) == .options)
        #expect(PlayerKeys.controller(.y) == .info)
        #expect(PlayerKeys.controller(.leftShoulder) == .previous)
        #expect(PlayerKeys.controller(.rightShoulder) == .next)
        #expect(PlayerKeys.controller(.left) == .left)
        #expect(PlayerKeys.controller(.down) == .down)
    }

    @Test func aHeldArrowSeeksFarther() {
        #expect(PlayerKeys.seek(.left, repeated: false) == -10_000)
        #expect(PlayerKeys.seek(.right, repeated: false) == 10_000)
        #expect(PlayerKeys.seek(.left, repeated: true) == -30_000)
        #expect(PlayerKeys.seek(.right, repeated: true) == 30_000)
        #expect(PlayerKeys.seek(.up, repeated: false) == nil)
    }

    @Test func aNumberGoesToItsTenthOfTheVideo() {
        #expect(PlayerKeys.position(number: 1, duration: 600_000) == 60_000)
        #expect(PlayerKeys.position(number: 9, duration: 600_000) == 540_000)
        #expect(PlayerKeys.position(number: 5, duration: 0) == nil)
        #expect(PlayerKeys.position(number: 0, duration: 600_000) == nil)
    }
}
