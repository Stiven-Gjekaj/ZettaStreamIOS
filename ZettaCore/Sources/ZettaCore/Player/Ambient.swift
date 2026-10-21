import Foundation

/// The ambient fill of the side bars. The player copies the frame at a tiny size a few times a
/// second, blurs it here, and stretches it behind the video. The video itself is not changed.
/// A pixel is ARGB in one number: alpha in the top 8 bits, then red, green, and blue.
public enum Ambient {
    /// The size of the copy of the frame. A small copy costs almost nothing.
    public static let width = 32
    public static let height = 18

    /// The time between two copies while the video plays.
    public static let intervalMs = 500

    /// A change of colour smaller than this, on average for each part of a pixel, is not drawn.
    public static let minChange = 6

    /// True when the video does not fill the screen, so the side bars have space. A video
    /// within 3 percent of the screen shape needs no fill. `pixelRatio` is the width of
    /// one video pixel divided by its height.
    public static func needed(videoWidth: Int, videoHeight: Int, pixelRatio: Float, screenWidth: Int, screenHeight: Int) -> Bool {
        if videoWidth <= 0 || videoHeight <= 0 || screenWidth <= 0 || screenHeight <= 0 { return false }
        let video = Float(videoWidth) * pixelRatio / Float(videoHeight)
        let screen = Float(screenWidth) / Float(screenHeight)
        return abs(video - screen) / screen > 0.03
    }

    /// A box blur of `radius` on ARGB `pixels`, two times in each direction, which looks soft.
    public static func blur(_ pixels: [UInt32], width: Int, height: Int, radius: Int) -> [UInt32] {
        var out = pixels
        for _ in 0..<2 {
            out = pass(out, width, height, radius, horizontal: true)
            out = pass(out, width, height, radius, horizontal: false)
        }
        return out
    }

    private static func pass(_ src: [UInt32], _ w: Int, _ h: Int, _ r: Int, horizontal: Bool) -> [UInt32] {
        var dst = [UInt32](repeating: 0, count: src.count)
        let lines = horizontal ? h : w
        let length = horizontal ? w : h
        for line in 0..<lines {
            for i in 0..<length {
                var a: UInt32 = 0, red: UInt32 = 0, g: UInt32 = 0, b: UInt32 = 0, n: UInt32 = 0
                for k in max(i - r, 0)...min(i + r, length - 1) {
                    let p = src[horizontal ? line * w + k : k * w + line]
                    a += p >> 24; red += p >> 16 & 0xFF; g += p >> 8 & 0xFF; b += p & 0xFF; n += 1
                }
                dst[horizontal ? line * w + i : i * w + line] = (a / n) << 24 | (red / n) << 16 | (g / n) << 8 | (b / n)
            }
        }
        return dst
    }

    /// The average change of each colour part between two copies. A small change is not drawn
    /// again, because each draw of the fill covers the full screen. Two copies of a different
    /// size, or two empty copies, give `Int.max`.
    public static func change(_ a: [UInt32], _ b: [UInt32]) -> Int {
        if a.count != b.count || a.isEmpty { return Int.max }
        var sum = 0
        for i in a.indices {
            let x = a[i], y = b[i]
            sum += abs(Int(x >> 16 & 0xFF) - Int(y >> 16 & 0xFF))
                + abs(Int(x >> 8 & 0xFF) - Int(y >> 8 & 0xFF))
                + abs(Int(x & 0xFF) - Int(y & 0xFF))
        }
        return sum / (a.count * 3)
    }
}
