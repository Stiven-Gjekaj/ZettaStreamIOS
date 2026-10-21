import Foundation

/// Compares versions of the form `MAJOR.MINOR.PATCH`, with an optional test label such
/// as `-rc1`. A version with a test label comes before the same version without one.
public enum Version {
    /// Tells if `latest` is newer than `current`.
    public static func isNewer(_ latest: String, than current: String) -> Bool {
        compare(latest, current) > 0
    }

    /// A negative number when `a` comes first, zero when the two are the same, otherwise a positive number.
    /// A part that is not a number counts as zero, and a missing part counts as zero.
    public static func compare(_ a: String, _ b: String) -> Int {
        let (coreA, testA) = split(a)
        let (coreB, testB) = split(b)
        for i in 0..<max(coreA.count, coreB.count) {
            let x = i < coreA.count ? coreA[i] : 0
            let y = i < coreB.count ? coreB[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        switch (testA, testB) {
        case _ where testA == testB: return 0
        case (nil, _): return 1
        case (_, nil): return -1
        case let (x?, y?): return compareTest(x, y)
        }
    }

    private static func split(_ version: String) -> (core: [Int], test: String?) {
        var text = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") { text.removeFirst() }
        let core: Substring
        let test: String?
        if let dash = text.firstIndex(of: "-") {
            core = text[..<dash]
            let after = text[text.index(after: dash)...]
            test = after.isEmpty ? nil : String(after)
        } else {
            core = Substring(text)
            test = nil
        }
        return (core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) ?? 0 }, test)
    }

    /// Compares two test labels, such as `rc2` and `rc10`, by their letters and then by their number.
    private static func compareTest(_ a: String, _ b: String) -> Int {
        let lettersA = String(a.prefix { !isDigit($0) })
        let lettersB = String(b.prefix { !isDigit($0) })
        if lettersA != lettersB { return lettersA < lettersB ? -1 : 1 }
        let x = Int(String(a.filter(isDigit))) ?? 0
        let y = Int(String(b.filter(isDigit))) ?? 0
        return x == y ? 0 : (x < y ? -1 : 1)
    }

    private static func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }
}
