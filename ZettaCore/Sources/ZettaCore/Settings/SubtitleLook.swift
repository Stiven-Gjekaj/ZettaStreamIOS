// The choices of the viewer settings. The raw value of each case is the name
// that the Android app writes into the settings file and into a backup.

public enum SubtitleSize: String, CaseIterable, Sendable, Codable {
    case small = "Small", normal = "Normal", large = "Large", huge = "Huge"

    public var label: String { rawValue }

    public var scale: Double {
        switch self {
        case .small: 0.8
        case .normal: 1
        case .large: 1.3
        case .huge: 1.6
        }
    }
}

/// The text color of subtitles, as ARGB.
public enum SubtitleColor: String, CaseIterable, Sendable, Codable {
    case white = "White", yellow = "Yellow", gray = "Gray", cyan = "Cyan"

    public var label: String { self == .gray ? "Light gray" : rawValue }

    public var argb: UInt32 {
        switch self {
        case .white: 0xFFFF_FFFF
        case .yellow: 0xFFFF_E14D
        case .gray: 0xFFD0_D0D0
        case .cyan: 0xFF7F_E7FF
        }
    }
}

/// How much the box behind subtitles hides the video.
public enum SubtitleBackground: String, CaseIterable, Sendable, Codable {
    case none = "None", light = "Light", medium = "Medium", dark = "Dark", solid = "Solid"

    public var label: String {
        switch self {
        case .none: "None"
        case .light: "25%"
        case .medium: "50%"
        case .dark: "75%"
        case .solid: "Solid"
        }
    }

    /// The opacity of the box, from 0 to 255.
    public var alpha: Int {
        switch self {
        case .none: 0
        case .light: 64
        case .medium: 128
        case .dark: 191
        case .solid: 255
        }
    }
}

public enum SubtitleFont: String, CaseIterable, Sendable, Codable {
    case `default` = "Default", sans = "Sans", serif = "Serif", mono = "Mono", bold = "Bold"

    public var label: String { self == .mono ? "Monospace" : rawValue }
}

/// The edge around each letter, so that text without a box stays readable.
public enum SubtitleEdge: String, CaseIterable, Sendable, Codable {
    case none = "None", outline = "Outline", shadow = "Shadow", raised = "Raised"

    public var label: String { self == .shadow ? "Drop shadow" : rawValue }
}

/// What fills the bars beside a video of another shape, such as an old 4:3 anime.
public enum SideBars: String, CaseIterable, Sendable, Codable {
    case black = "Black", ambient = "Ambient", stretch = "Stretch"

    public var label: String {
        switch self {
        case .black: "Black"
        case .ambient: "Ambient blur"
        case .stretch: "Stretch to fill"
        }
    }
}
