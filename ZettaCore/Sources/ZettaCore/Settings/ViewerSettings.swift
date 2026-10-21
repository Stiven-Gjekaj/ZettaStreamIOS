import Foundation

/// The choices of the viewer. Each value has a default that works with no change.
/// The JSON keys are the keys of the Android app.
public struct ViewerSettings: Hashable, Sendable {
    public var subtitlesOn = false
    public var subtitleLanguage = "en"
    public var audioLanguage = ""
    public var subtitleSize = SubtitleSize.normal
    public var subtitleColor = SubtitleColor.white
    public var subtitleBackground = SubtitleBackground.none
    public var subtitleFont = SubtitleFont.default
    public var subtitleEdge = SubtitleEdge.outline
    public var sideBars = SideBars.ambient
    public var videoFilter = VideoFilter.none
    public var autoplayNext = true
    public var autoSkipIntro = false
    /// The TV switches to the frame rate of the video, so that a pan does not judder.
    public var matchFrameRate = true
    public var confirmChannel = true
    public var showTorrents = true
    public var directFirst = false
    public var torrentUpload = false
    public var vpnNotice = true
    /// The sound plays this much later than the picture. It fixes a sound system that adds a delay.
    public var audioDelayMs = 0
    /// The last searches, newest first.
    public var searchHistory: [String] = []
    /// The keys of the home rows in the order that the viewer chose. A row that is not here keeps its place after them.
    public var rowOrder: [String] = []
    /// The keys of the home rows that the viewer turned off.
    public var hiddenRows: Set<String> = []

    public init() {}
}

extension ViewerSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case subtitlesOn, subtitleLanguage, audioLanguage, subtitleSize, subtitleColor, subtitleBackground, subtitleFont
        case subtitleEdge, sideBars, videoFilter, autoplayNext, autoSkipIntro, matchFrameRate, confirmChannel, showTorrents
        case directFirst, torrentUpload, vpnNotice, audioDelayMs, searchHistory, rowOrder, hiddenRows
    }

    /// A missing key, or a null, takes its default. A choice that a newer version removed,
    /// such as the side bars "Zoom", also becomes the default. Without this, one old value
    /// makes the whole file unreadable, and all the settings reset.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ViewerSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        func choice<T: RawRepresentable<String>>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(String.self, forKey: key).flatMap(T.init(rawValue:)) ?? fallback
        }
        subtitlesOn = try value(.subtitlesOn, d.subtitlesOn)
        subtitleLanguage = try value(.subtitleLanguage, d.subtitleLanguage)
        audioLanguage = try value(.audioLanguage, d.audioLanguage)
        subtitleSize = try choice(.subtitleSize, d.subtitleSize)
        subtitleColor = try choice(.subtitleColor, d.subtitleColor)
        subtitleBackground = try choice(.subtitleBackground, d.subtitleBackground)
        subtitleFont = try choice(.subtitleFont, d.subtitleFont)
        subtitleEdge = try choice(.subtitleEdge, d.subtitleEdge)
        sideBars = try choice(.sideBars, d.sideBars)
        videoFilter = try choice(.videoFilter, d.videoFilter)
        autoplayNext = try value(.autoplayNext, d.autoplayNext)
        autoSkipIntro = try value(.autoSkipIntro, d.autoSkipIntro)
        matchFrameRate = try value(.matchFrameRate, d.matchFrameRate)
        confirmChannel = try value(.confirmChannel, d.confirmChannel)
        showTorrents = try value(.showTorrents, d.showTorrents)
        directFirst = try value(.directFirst, d.directFirst)
        torrentUpload = try value(.torrentUpload, d.torrentUpload)
        vpnNotice = try value(.vpnNotice, d.vpnNotice)
        audioDelayMs = try value(.audioDelayMs, d.audioDelayMs)
        searchHistory = try value(.searchHistory, d.searchHistory)
        rowOrder = try value(.rowOrder, d.rowOrder)
        hiddenRows = try value(.hiddenRows, d.hiddenRows)
    }

    /// Each key is written, as the Android app does. A set goes in order, so the same settings give the same text.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(subtitlesOn, forKey: .subtitlesOn)
        try c.encode(subtitleLanguage, forKey: .subtitleLanguage)
        try c.encode(audioLanguage, forKey: .audioLanguage)
        try c.encode(subtitleSize, forKey: .subtitleSize)
        try c.encode(subtitleColor, forKey: .subtitleColor)
        try c.encode(subtitleBackground, forKey: .subtitleBackground)
        try c.encode(subtitleFont, forKey: .subtitleFont)
        try c.encode(subtitleEdge, forKey: .subtitleEdge)
        try c.encode(sideBars, forKey: .sideBars)
        try c.encode(videoFilter, forKey: .videoFilter)
        try c.encode(autoplayNext, forKey: .autoplayNext)
        try c.encode(autoSkipIntro, forKey: .autoSkipIntro)
        try c.encode(matchFrameRate, forKey: .matchFrameRate)
        try c.encode(confirmChannel, forKey: .confirmChannel)
        try c.encode(showTorrents, forKey: .showTorrents)
        try c.encode(directFirst, forKey: .directFirst)
        try c.encode(torrentUpload, forKey: .torrentUpload)
        try c.encode(vpnNotice, forKey: .vpnNotice)
        try c.encode(audioDelayMs, forKey: .audioDelayMs)
        try c.encode(searchHistory, forKey: .searchHistory)
        try c.encode(rowOrder, forKey: .rowOrder)
        try c.encode(hiddenRows.sorted(), forKey: .hiddenRows)
    }
}

/// Keeps the viewer settings in the private storage of the app.
public final class SettingsStore: Sendable {
    private let store: JSONFile<ViewerSettings>

    public init(file: URL) {
        store = JSONFile(file: file) { ViewerSettings() }
    }

    public var settings: ViewerSettings { store.value }

    /// Gives the settings now, and then each changed version.
    public func updates() -> AsyncStream<ViewerSettings> { store.updates() }

    public func update(_ change: (inout ViewerSettings) -> Void) throws {
        try store.update(change)
    }

    /// Reads the settings of another profile from `next`. Later changes go to that file.
    public func switchTo(_ next: URL) {
        store.switchTo(next) { ViewerSettings() }
    }

    /// The languages that the settings offer, as ISO 639-1 codes. An empty code means the original.
    public static let languages: [(code: String, name: String)] = [
        ("", "Original"), ("en", "English"), ("sq", "Albanian"), ("ja", "Japanese"), ("it", "Italian"),
        ("de", "German"), ("fr", "French"), ("es", "Spanish"), ("pt", "Portuguese"), ("tr", "Turkish"),
        ("ar", "Arabic"), ("ru", "Russian"), ("ko", "Korean"), ("zh", "Chinese"),
    ]

    public static func languageName(_ code: String) -> String {
        languages.first { $0.code == code }?.name ?? code
    }

    /// Gives the next item of `options` after `current`, and the first after the last.
    /// An item that is not in `options` gives the first.
    public static func next<T: Equatable>(_ options: [T], _ current: T) -> T {
        options[((options.firstIndex(of: current) ?? -1) + 1) % options.count]
    }
}
