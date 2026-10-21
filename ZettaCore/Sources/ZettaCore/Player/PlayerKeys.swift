/// A key of a keyboard or a button of a game controller, as the player uses it.
/// The keys are those of a TV remote, as in the "Universal remote keys" of the Android app.
public enum PlayerKey: Hashable, Sendable {
    /// OK: a short press plays or pauses, or skips while a skip prompt shows. A long press opens the options.
    case select
    case back
    case left, right, up, down
    case options
    case info
    case playPause
    case next, previous
    case subtitles, audio
    case skip
    /// A number from 1 to 9. It goes to that tenth of the video.
    case number(Int)
}

/// A button of a game controller.
public enum ControllerButton: Hashable, Sendable {
    case a, b, x, y
    case leftShoulder, rightShoulder
    case left, right, up, down
    case menu, options
}

/// Changes the keys of a keyboard and the buttons of a game controller into player keys.
public enum PlayerKeys {
    /// The seek of one press of Left or Right, and of each repeat while the key is held, in milliseconds.
    /// These are the steps of the Android app.
    public static let seekStep = 10_000
    public static let seekFast = 30_000
    /// The seconds that a press of OK lasts before it opens the options.
    public static let longPress = 0.5
    /// The seconds before a held key repeats, and between two repeats.
    public static let repeatDelay = 0.5
    public static let repeatInterval = 0.25

    /// The key of a keyboard, from its USB HID usage, as `GCKeyCode` and `UIKeyboardHIDUsage` give it.
    /// The letters follow the large video sites: K plays or pauses, and J and L seek.
    public static func keyboard(_ usage: Int) -> PlayerKey? {
        switch usage {
        case 0x28, 0x58: .select // Return, Enter of the keypad
        case 0x29: .back // Escape
        case 0x2C, 0x0E: .playPause // Space, K
        case 0x50, 0x0D: .left // Left arrow, J
        case 0x4F, 0x0F: .right // Right arrow, L
        case 0x52: .up
        case 0x51: .down
        case 0x2B: .options // Tab
        case 0x0C: .info // I
        case 0x11, 0x4E: .next // N, Page Down
        case 0x13, 0x4B: .previous // P, Page Up
        case 0x06: .subtitles // C
        case 0x04: .audio // A
        case 0x16: .skip // S
        case 0x1E...0x26: .number(usage - 0x1E + 1) // 1 to 9 of the top row
        case 0x59...0x61: .number(usage - 0x59 + 1) // 1 to 9 of the keypad
        default: nil
        }
    }

    /// The key of a button of a game controller. The shoulder buttons change the episode or the channel.
    public static func controller(_ button: ControllerButton) -> PlayerKey {
        switch button {
        case .a: .select
        case .b: .back
        case .x, .menu: .options
        case .y, .options: .info
        case .leftShoulder: .previous
        case .rightShoulder: .next
        case .left: .left
        case .right: .right
        case .up: .up
        case .down: .down
        }
    }

    /// The position that a number key goes to, in milliseconds. Nil with no length.
    public static func position(number: Int, duration: Int) -> Int? {
        guard duration > 0, (1...9).contains(number) else { return nil }
        return duration / 10 * number
    }

    /// The seek of a press of Left or Right. A repeat while the key is held seeks farther.
    public static func seek(_ key: PlayerKey, repeated: Bool) -> Int? {
        let step = repeated ? seekFast : seekStep
        switch key {
        case .left: return -step
        case .right: return step
        default: return nil
        }
    }
}
