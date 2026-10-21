import Foundation

/// What the name and the title of a stream say about it. Each field is nil when the text does not say.
public struct StreamInfo: Hashable, Sendable, Codable {
    public var seeders: Int?
    public var resolution: Int?
    public var hdr: String?
    public var codec: String?
    public var source: String?
    public var dualAudio = false
    public var sizeBytes: Int64?
    public var group: String?

    public init(seeders: Int? = nil, resolution: Int? = nil, hdr: String? = nil, codec: String? = nil, source: String? = nil,
                dualAudio: Bool = false, sizeBytes: Int64? = nil, group: String? = nil) {
        self.seeders = seeders
        self.resolution = resolution
        self.hdr = hdr
        self.codec = codec
        self.source = source
        self.dualAudio = dualAudio
        self.sizeBytes = sizeBytes
        self.group = group
    }

    /// Reads the text of a stream. Addons write the same facts in many forms.
    public init(_ stream: AddonStream) {
        self = StreamInfo.parse([stream.name, stream.title, stream.description, stream.hints.filename]
            .compactMap { $0 }.joined(separator: "\n"))
    }

    /// The short labels that the list of streams shows.
    public var badges: [String] {
        [
            resolution.map(Self.resolutionLabel),
            hdr,
            codec,
            source,
            dualAudio ? "Dual audio" : nil,
            sizeBytes.map(Self.formatSize),
            seeders.map { "\($0) seeders" },
        ].compactMap { $0 }
    }

    /// "4K" for 2160p and more, else the number of lines, such as "1080p".
    static func resolutionLabel(_ resolution: Int) -> String {
        resolution >= 2160 ? "4K" : "\(resolution)p"
    }

    private static let seederPatterns = [
        StreamRegex(#"👤\s*(\d+)"#),
        StreamRegex(#"👥\s*(\d+)"#),
        StreamRegex(#"🌱\s*(\d+)"#),
        StreamRegex(#"(?i)\bseed(?:er)?s?\s*[:=]?\s*(\d+)"#),
        StreamRegex(#"(?i)(\d+)\s*seed(?:er)?s?\b"#),
        StreamRegex(#"(?i)\bS\s*:\s*(\d+)\b"#),
    ]
    private static let resolutionPattern = StreamRegex(#"(?i)\b(2160|1440|1080|720|576|480|360)p\b"#)
    private static let fourK = StreamRegex(#"(?i)\b(4k|uhd)\b"#)
    private static let sizePattern = StreamRegex(#"(?i)(\d+(?:[.,]\d+)?)\s*(TB|GB|MB|GiB|MiB)\b"#)
    private static let groupPattern = StreamRegex(#"^\s*\[([^\]]{2,30})\]"#, options: .anchorsMatchLines)

    private static let hdrPatterns = [
        ("Dolby Vision", StreamRegex(#"(?i)\b(dolby\s?vision|dovi|\bDV\b)"#)),
        ("HDR10+", StreamRegex(#"(?i)\bHDR10\+"#)),
        ("HDR", StreamRegex(#"(?i)\bHDR(10)?\b"#)),
    ]
    private static let codecPatterns = [
        ("HEVC", StreamRegex(#"(?i)\b(x265|h\.?265|hevc)\b"#)),
        ("AV1", StreamRegex(#"(?i)\bav1\b"#)),
        ("H.264", StreamRegex(#"(?i)\b(x264|h\.?264|avc)\b"#)),
    ]
    private static let sourcePatterns = [
        ("Remux", StreamRegex(#"(?i)\bremux\b"#)),
        ("BluRay", StreamRegex(#"(?i)\b(blu-?ray|bdrip|brrip|bd)\b"#)),
        ("WEB-DL", StreamRegex(#"(?i)\bweb-?dl\b"#)),
        ("WEBRip", StreamRegex(#"(?i)\bweb-?rip\b"#)),
        ("HDTV", StreamRegex(#"(?i)\bhdtv\b"#)),
        ("CAM", StreamRegex(#"(?i)\b(cam|hdcam|camrip|telesync)\b"#)),
    ]
    private static let dualPattern = StreamRegex(#"(?i)\b(dual[\s.-]?audio|multi[\s.-]?audio|eng(lish)?\s?dub|dubbed)\b"#)

    /// The first label whose pattern is in the text.
    private static func first(_ patterns: [(String, StreamRegex)], in text: String) -> String? {
        patterns.first { $0.1.matches(text) }?.0
    }

    /// Reads a number as the Android app does: a number that does not fit in 32 bits is not a number.
    private static func int32(_ text: String) -> Int? {
        Int32(text).map(Int.init)
    }

    public static func parse(_ text: String) -> StreamInfo {
        let seeders = seederPatterns.lazy.compactMap { $0.firstGroup(in: text).flatMap(int32) }.first
        let resolution = resolutionPattern.allGroups(in: text).compactMap { int32($0[1]) }.max()
            ?? (fourK.matches(text) ? 2160 : nil)
        let size = sizePattern.allGroups(in: text).compactMap { groups -> Int64? in
            guard let number = Double(groups[1].replacingOccurrences(of: ",", with: ".")) else { return nil }
            let unit: Double = switch groups[2].uppercased() {
            case "TB": 1e12
            case "GB": 1e9
            case "GIB": 1_073_741_824
            case "MB": 1e6
            default: 1_048_576
            }
            let bytes = number * unit
            // A number too large for 64 bits is not a size.
            guard bytes.isFinite, bytes < 9.2e18 else { return nil }
            return Int64(bytes)
        }.max()
        return StreamInfo(
            seeders: seeders,
            resolution: resolution,
            hdr: first(hdrPatterns, in: text),
            codec: first(codecPatterns, in: text),
            source: first(sourcePatterns, in: text),
            dualAudio: dualPattern.matches(text),
            sizeBytes: size,
            group: groupPattern.firstGroup(in: text)
        )
    }

    /// Writes a size such as "1.4 GB" or "700 MB". A half rounds up, as in the Android app.
    public static func formatSize(_ bytes: Int64) -> String {
        if Double(bytes) >= 1e9 {
            let tenths = (Double(bytes) / 1e9 * 10).rounded(.toNearestOrAwayFromZero) / 10
            return String(format: "%.1f GB", tenths)
        }
        return "\(bytes / 1_000_000) MB"
    }

    /// Scores how much `candidate` is like `current`, so that the next episode
    /// plays from a source with the same data and not only the same name.
    public static func similarity(_ current: StreamInfo, _ candidate: StreamInfo) -> Int {
        var score = 0
        func same<T: Equatable>(_ a: T?, _ b: T?, _ points: Int, _ penalty: Int = 0) {
            if let a, let b { score += a == b ? points : -penalty }
        }
        same(current.resolution, candidate.resolution, 40, 30)
        same(current.codec, candidate.codec, 15, 5)
        same(current.hdr, candidate.hdr, 10, 5)
        same(current.source, candidate.source, 10, 0)
        same(current.group, candidate.group, 30, 0)
        score += current.dualAudio == candidate.dualAudio ? 20 : -20
        return score
    }
}
