import Foundation

/// Sorts the error lines of VLC into a `PlaybackFault`. VLC gives no error code. It only
/// writes lines of text to its log, so the app reads the words of those lines.
public enum FaultLog {
    /// The most lines that the player keeps. The fault is in the last lines.
    public static let keptLines = 20

    /// The fault of the lines. A decoder fault wins over a refused stream, a refused stream
    /// wins over no connection, and so on, because VLC often writes a general line after the
    /// line that tells the cause.
    public static func fault(_ lines: [String]) -> PlaybackFault {
        let lower = lines.map { $0.lowercased() }
        for (kind, test) in rules where lower.contains(where: test) { return kind }
        return .other(name: "player error")
    }

    /// The line that tells the cause, for the message, such as "HTTP 403 error". At most 80 letters.
    public static func reason(_ lines: [String]) -> String? {
        let lower = lines.map { $0.lowercased() }
        for (_, test) in rules {
            if let index = lower.lastIndex(where: test) { return short(lines[index]) }
        }
        return lines.last.map(short)
    }

    private static func short(_ line: String) -> String {
        String(line.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
    }

    private static let httpStatus = StreamRegex(#"\b(http|status|error|response)\s*:?\s*[45][0-9][0-9]\b"#)

    private static func any(_ words: [String]) -> @Sendable (String) -> Bool {
        { line in words.contains { line.contains($0) } }
    }

    private static let rules: [(PlaybackFault, @Sendable (String) -> Bool)] = [
        (.decoder, { line in
            line.contains("could not decode") || line.contains("no suitable decoder")
                || (line.contains("codec") && (line.contains("not supported") || line.contains("unsupported")))
        }),
        (.refused, { line in
            httpStatus.matches(line)
                || ["forbidden", "unauthorized", "not found", "permission denied", "access denied"].contains { line.contains($0) }
        }),
        (.noConnection, any(["cannot resolve", "connection refused", "connection failed", "cannot connect",
                             "timed out", "timeout", "host unreachable", "network is unreachable", "no route to host"])),
        (.notVideo, any(["no suitable demux", "unknown format", "can't recognize", "cannot recognize",
                         "unsupported format", "corrupt", "malformed", "invalid data"])),
        (.network, any(["connection reset", "broken pipe", "read error", "connection lost", "network",
                        "socket", "tls", "ssl", "end of stream"])),
        // A web page gives only the general lines of VLC. They come last, because each fault writes them.
        (.notVideo, any(["can't be opened", "unable to open the mrl"])),
    ]
}

extension PlayerErrors {
    /// VLC often ends a stream that drops in the middle with no error: the player only stops.
    /// An end this far before the known length is a network fault, not the end of the video.
    public static let earlyEndMarginMs = 30_000

    /// True when a stop at `position` is a fault. A stream with no known length, such as a
    /// live channel, must not end, so each end of it is a fault.
    public static func endedEarly(position: Int, duration: Int) -> Bool {
        duration <= 0 || position < duration - earlyEndMarginMs
    }
}
