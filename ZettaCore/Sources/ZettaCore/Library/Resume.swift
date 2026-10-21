/// Decides if a saved position fits the source that plays now.
public enum Resume {
    /// A position this near the end does not resume, because the video would end at once.
    public static let endMargin = 15_000

    /// True when `position` is before the end of a video of `duration` milliseconds, with a margin.
    public static func fits(position: Int, duration: Int) -> Bool {
        duration <= 0 || position < duration - endMargin
    }
}
