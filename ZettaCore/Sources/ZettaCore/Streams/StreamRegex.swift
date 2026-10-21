import Foundation

/// A regular expression that a static constant can hold. The patterns use the
/// ICU syntax, which reads the Java patterns of the Android app the same way.
struct StreamRegex: @unchecked Sendable {
    private let regex: NSRegularExpression

    /// Stops on a bad pattern. Each pattern is a constant of the code, so a test finds the fault.
    init(_ pattern: String, options: NSRegularExpression.Options = []) {
        regex = try! NSRegularExpression(pattern: pattern, options: options)
    }

    func matches(_ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// The text of the first group in the first match.
    func firstGroup(in text: String) -> String? {
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return Self.group(match, 1, in: text)
    }

    /// The texts of the groups of each match. A group that did not take part is an empty text.
    func allGroups(in text: String) -> [[String]] {
        regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (0..<match.numberOfRanges).map { Self.group(match, $0, in: text) ?? "" }
        }
    }

    func replacing(in text: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        guard let range = Range(match.range(at: index), in: text) else { return nil }
        return String(text[range])
    }
}
