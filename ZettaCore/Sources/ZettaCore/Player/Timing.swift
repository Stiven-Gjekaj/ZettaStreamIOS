import Foundation

/// The timing that the viewer sets in the player. A positive subtitle delay shows the
/// subtitles later. A positive audio delay plays the sound later than the picture.
public struct Timing: Hashable, Sendable {
    public var subtitleDelayMs = 0
    public var audioDelayMs = 0

    public init(subtitleDelayMs: Int = 0, audioDelayMs: Int = 0) {
        self.subtitleDelayMs = subtitleDelayMs
        self.audioDelayMs = audioDelayMs
    }

    public static let subtitleStep = 250
    public static let subtitleLimit = 30_000
    public static let audioStep = 50
    public static let audioLimit = 2_000

    /// The next value after one step, kept inside the limit.
    public static func step(_ current: Int, direction: Int, step: Int, limit: Int) -> Int {
        min(max(current + direction * step, -limit), limit)
    }

    /// A delay for the options panel, such as "+1.25 s" or "None".
    /// A zero at the end of the seconds is not shown.
    public static func label(_ ms: Int) -> String {
        if ms == 0 { return "None" }
        let sign = ms < 0 ? "-" : "+"
        // Hundredths of a second, with a half rounded up.
        let hundredths = (ms.magnitude + 5) / 10
        let whole = hundredths / 100
        let part = hundredths % 100
        if part == 0 { return "\(sign)\(whole) s" }
        if part % 10 == 0 { return "\(sign)\(whole).\(part / 10) s" }
        return "\(sign)\(whole).\(part < 10 ? "0" : "")\(part) s"
    }

    /// A position for the player, such as "4:05" or "1:02:03". A negative time is not known.
    public static func formatTime(_ ms: Int) -> String {
        if ms < 0 { return "--:--" }
        let s = ms / 1000
        func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        if s >= 3600 { return "\(s / 3600):\(two(s / 60 % 60)):\(two(s % 60))" }
        return "\(s / 60):\(two(s % 60))"
    }
}
