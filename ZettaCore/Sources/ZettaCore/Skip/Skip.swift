import Foundation

public enum SkipKind: String, Hashable, Sendable, CaseIterable {
    case opening, ending, recap

    /// The text of the prompt while this part plays.
    public var promptLabel: String {
        switch self {
        case .opening: return "Skip intro"
        case .ending: return "Skip ending"
        case .recap: return "Skip recap"
        }
    }

    /// The message after the player skips this part.
    public var skippedMessage: String {
        switch self {
        case .opening: return "Skipped the opening"
        case .ending: return "Skipped the ending"
        case .recap: return "Skipped the recap"
        }
    }
}

/// One part of an episode that the viewer can skip. Times are in milliseconds.
public struct SkipRange: Hashable, Sendable {
    public var kind: SkipKind
    public var start: Int
    public var end: Int

    public init(kind: SkipKind, start: Int, end: Int) {
        self.kind = kind
        self.start = start
        self.end = end
    }

    /// True from the start up to the end. The end itself is not in the range.
    public func contains(_ position: Int) -> Bool { position >= start && position < end }
}

/// What the skip button does at one position.
public enum SkipAction: Hashable, Sendable {
    case seekTo(position: Int, kind: SkipKind)
    case jump(by: Int)
}

/// The rules of the skip button, the skip prompt, auto-skip, and the next episode countdown.
public enum Skip {
    /// The jump when no times are known.
    public static let fallback = 85_000

    /// The message after the fallback jump.
    public static let fallbackMessage = "Skipped 85 seconds"

    /// How long before an opening the button still skips it, for a cold open of a few seconds.
    static let lead = 3 * 60_000

    /// The time before the end where the "Next episode" countdown starts when no ending is known.
    public static let countdownLead = 20_000

    /// The length of the "Next episode" countdown.
    public static let countdownLength = 10_000

    /// How long before the countdown the app finds the stream of the next episode.
    public static let prepareAhead = 60_000

    /// Decides what the button does. Inside a range, it goes to the end of the range.
    /// Before the opening (in the first minutes), it skips the opening. Otherwise it jumps.
    public static func action(_ ranges: [SkipRange], position: Int) -> SkipAction {
        if let range = ranges.first(where: { $0.contains(position) }) {
            return .seekTo(position: range.end, kind: range.kind)
        }
        let opening = ranges
            .filter { $0.kind == .opening && position < $0.start && $0.start - position <= lead }
            .min { $0.start < $1.start }
        if let opening { return .seekTo(position: opening.end, kind: opening.kind) }
        return .jump(by: fallback)
    }

    /// Where the "Next episode" countdown starts: at the ending when the times have one,
    /// otherwise 20 seconds before the end. Nil when the duration is not known yet.
    public static func countdownStart(_ ranges: [SkipRange], duration: Int) -> Int? {
        if duration <= 0 { return nil }
        if let ending = ranges.last(where: { $0.kind == .ending && $0.start < duration }) { return ending.start }
        return max(duration - countdownLead, 0)
    }

    /// True when the app finds the next episode, about one minute before the countdown.
    public static func shouldPrepareNext(_ ranges: [SkipRange], duration: Int, position: Int) -> Bool {
        guard let start = countdownStart(ranges, duration: duration) else { return false }
        return position >= start - prepareAhead
    }

    /// The opening or the recap that auto-skip jumps over at this position.
    /// A range that was skipped one time is not skipped again, so that the
    /// viewer can go back and watch it. `done` holds the starts of the skipped ranges.
    public static func autoSkip(_ ranges: [SkipRange], position: Int, done: Set<Int>) -> SkipRange? {
        ranges.first { $0.kind != .ending && $0.contains(position) && !done.contains($0.start) }
    }

    /// The range that the player prompts for at this position, if any.
    public static func current(_ ranges: [SkipRange], position: Int) -> SkipRange? {
        ranges.first { $0.contains(position) }
    }

    /// Reads the MyAnimeList ID out of a Kitsu mappings answer.
    public static func malIdFromKitsu(_ data: Data) -> Int? {
        guard let root = try? JSONValue.parse(data), root.objectValue != nil,
              let items = root["data"]?.arrayValue else { return nil }
        // An item that is not an object makes the full answer bad, as on Android.
        guard items.allSatisfy({ $0.objectValue != nil }) else { return nil }
        for item in items {
            guard let attributes = item["attributes"], attributes.objectValue != nil else { continue }
            guard attributes["externalSite"]?.stringValue == "myanimelist/anime" else { continue }
            if let id = attributes["externalId"]?.stringValue.flatMap({ Int($0) }) { return id }
        }
        return nil
    }

    /// Reads an AniSkip answer. Times are seconds in the answer and milliseconds in the result.
    public static func parseAniSkip(_ data: Data) -> [SkipRange] {
        guard let root = try? JSONValue.parse(data), root.objectValue != nil,
              root["found"]?.boolValue == true,
              let results = root["results"]?.arrayValue,
              results.allSatisfy({ $0.objectValue != nil }) else { return [] }
        let types = Set(results.compactMap { $0["skipType"]?.stringValue })
        // A "mixed" range is a version of the opening or the ending that is mixed into the episode.
        // When the plain range exists too, the two overlap, so the plain range wins.
        let ranges: [SkipRange] = results.compactMap { result in
            let kind: SkipKind
            switch result["skipType"]?.stringValue {
            case "op": kind = .opening
            case "mixed-op" where !types.contains("op"): kind = .opening
            case "ed": kind = .ending
            case "mixed-ed" where !types.contains("ed"): kind = .ending
            case "recap": kind = .recap
            default: return nil
            }
            guard let interval = result["interval"], interval.objectValue != nil,
                  let start = seconds(interval["startTime"]),
                  let end = seconds(interval["endTime"]),
                  end > start else { return nil }
            return SkipRange(kind: kind, start: Int(start * 1000), end: Int(end * 1000))
        }
        return ranges.enumerated()
            .sorted { $0.element.start != $1.element.start ? $0.element.start < $1.element.start : $0.offset < $1.offset }
            .map(\.element)
    }

    /// A number of seconds. A text that holds a number also gives it.
    private static func seconds(_ value: JSONValue?) -> Double? {
        switch value {
        case .number(let number)?: return number.isFinite ? number : nil
        case .string(let text)?: return Double(text).flatMap { $0.isFinite ? $0 : nil }
        default: return nil
        }
    }

    /// Reads the Kitsu ID and the episode from a video ID such as `kitsu:1376:5`.
    public static func kitsuEpisode(_ videoId: String) -> (kitsu: Int, episode: Int)? {
        let parts = videoId.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3, parts[0] == "kitsu",
              let id = Int(parts[1]), let episode = parts.last.flatMap({ Int($0) }) else { return nil }
        return (id, episode)
    }
}
