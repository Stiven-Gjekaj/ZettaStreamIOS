import Foundation

/// The names and the order of the subtitle tracks in the player.
public enum SubtitleLabels {
    /// The most tracks of one language that the player lists. OpenSubtitles can give 70 tracks for one film.
    public static let tracksPerLanguage = 3

    /// The names are always in English, as on Android.
    private static let english = Locale(identifier: "en_US_POSIX")

    /// The codes of OpenSubtitles, and the older bibliographic codes, which Foundation does not read.
    private static let openSubtitlesCodes: [String: String] = [
        "pob": "pt-BR", "pom": "pt-MZ", "zht": "zh-Hant", "zhe": "zh", "spn": "es-419", "scc": "sr", "mne": "sr-ME",
        "alb": "sq", "arm": "hy", "baq": "eu", "bur": "my", "chi": "zh", "cze": "cs", "dut": "nl", "fre": "fr",
        "geo": "ka", "ger": "de", "gre": "el", "ice": "is", "mac": "mk", "mao": "mi", "may": "ms", "per": "fa",
        "rum": "ro", "slo": "sk", "tib": "bo", "wel": "cy",
    ]

    /// The two-letter code of each three-letter code, such as "sq" for "sqi".
    private static let threeLetterCodes: [String: String] = {
        var codes: [String: String] = [:]
        for language in Locale.LanguageCode.isoLanguageCodes where language.identifier.count == 2 {
            if let three = language.identifier(.alpha3) { codes[three] = language.identifier }
        }
        return codes
    }()

    /// Gives a standard language tag. Subtitle addons often give three-letter
    /// codes such as "sqi", and OpenSubtitles has its own codes such as "pob".
    public static func languageTag(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        return openSubtitlesCodes[lower] ?? threeLetterCodes[lower] ?? trimmed
    }

    /// The name of a language code such as "eng" or "sq". An unknown code stays as it is.
    public static func languageName(_ code: String) -> String {
        if code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Subtitle" }
        let tag = Tag(languageTag(code))
        guard !tag.language.isEmpty,
              let name = english.localizedString(forLanguageCode: tag.language), !name.isEmpty,
              name.lowercased() != tag.language else { return code }
        // A script or a region shows after the language, such as "Portuguese (Brazil)".
        let details = [
            tag.script.flatMap { english.localizedString(forScriptCode: $0) },
            tag.region.flatMap { english.localizedString(forRegionCode: $0) },
        ].compactMap { $0 }
        return details.isEmpty ? name : "\(name) (\(details.joined(separator: ", ")))"
    }

    /// Puts the subtitles of `preferred` first, then the other languages in the order
    /// of the addons, with at most `tracksPerLanguage` tracks of each language.
    public static func arrange(_ subtitles: [Subtitle], preferred: String) -> [Subtitle] {
        func primary(_ code: String) -> String {
            let language = Tag(languageTag(code)).language
            return language.isEmpty ? code.lowercased() : language
        }
        var order: [String] = []
        var byLanguage: [String: [Subtitle]] = [:]
        for subtitle in subtitles {
            let language = primary(subtitle.lang)
            if byLanguage[language] == nil { order.append(language) }
            byLanguage[language, default: []].append(subtitle)
        }
        let want = primary(preferred)
        let wanted = preferred.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : order.filter { $0 == want }
        return (wanted + order.filter { !wanted.contains($0) }).flatMap { byLanguage[$0, default: []].prefix(tracksPerLanguage) }
    }

    /// Gives each subtitle a readable label. Two tracks in one language become "English 1" and "English 2".
    public static func labels(_ subtitles: [Subtitle]) -> [(subtitle: Subtitle, label: String)] {
        let names = subtitles.map { languageName($0.lang) }
        let totals = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
        var seen: [String: Int] = [:]
        return zip(subtitles, names).map { subtitle, name in
            seen[name, default: 0] += 1
            return (subtitle, totals[name, default: 0] > 1 ? "\(name) \(seen[name]!)" : name)
        }
    }

    /// The parts of a language tag such as "zh-Hant" or "pt-BR", read as a BCP 47 tag is.
    /// A tag that is not well formed has an empty language.
    private struct Tag {
        var language = ""
        var script: String?
        var region: String?

        init(_ text: String) {
            let parts = text.split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
            guard let first = parts.first, Self.isLetters(first), (2...3).contains(first.count) || (5...8).contains(first.count)
            else { return }
            language = first.lowercased()
            var rest = parts.dropFirst()
            if let next = rest.first, next.count == 4, Self.isLetters(next) {
                script = next.prefix(1).uppercased() + next.dropFirst().lowercased()
                rest = rest.dropFirst()
            }
            if let next = rest.first,
               (next.count == 2 && Self.isLetters(next)) || (next.count == 3 && next.allSatisfy { $0.isASCII && $0.isNumber }) {
                region = next.uppercased()
            }
        }

        private static func isLetters(_ text: String) -> Bool { text.allSatisfy { $0.isASCII && $0.isLetter } }
    }
}
