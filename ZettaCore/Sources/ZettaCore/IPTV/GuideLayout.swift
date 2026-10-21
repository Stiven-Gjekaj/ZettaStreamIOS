import Foundation

/// One programme in the guide grid. `offset` and `width` are parts of the time window, from 0 to 1.
public struct GuideBlock: Hashable, Sendable {
    public var programme: Programme
    public var offset: Double
    public var width: Double

    public init(programme: Programme, offset: Double, width: Double) {
        self.programme = programme
        self.offset = offset
        self.width = width
    }
}

/// Places the programmes of a channel on the time line of the guide grid.
public enum GuideLayout {
    public static let halfHour: Int64 = 30 * 60_000

    /// The grid shows three hours from the last full or half hour, so the programme on now is in it.
    public static let span: Int64 = 6 * halfHour

    public static func windowStart(_ now: Int64) -> Int64 { now - now % halfHour }

    /// The programmes that are in the window, cut at its edges.
    public static func blocks(_ programmes: [Programme], from: Int64, span: Int64 = span) -> [GuideBlock] {
        let to = from + span
        let shown = programmes.filter { $0.stop > from && $0.start < to && $0.stop > $0.start }
        return Xmltv.sortedByStart(shown).map {
            let start = max($0.start, from)
            let stop = min($0.stop, to)
            return GuideBlock(programme: $0, offset: Double(start - from) / Double(span), width: Double(stop - start) / Double(span))
        }
    }
}
