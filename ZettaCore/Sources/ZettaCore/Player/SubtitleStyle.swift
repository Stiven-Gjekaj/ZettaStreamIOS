import Foundation

/// The parts of the subtitle style that do not need a screen.
/// The style of the viewer replaces a style in the subtitle file.
public enum SubtitleStyle {
    /// The steps of the subtitle size. The raw value is the name that the Android app saves.
    public enum Size: String, Hashable, Sendable, CaseIterable {
        case small = "Small"
        case normal = "Normal"
        case large = "Large"
        case huge = "Huge"

        public var label: String { rawValue }

        /// The size as a multiple of the normal size.
        public var scale: Float {
            switch self {
            case .small: return 0.8
            case .normal: return 1
            case .large: return 1.3
            case .huge: return 1.6
            }
        }
    }

    /// The height of the normal subtitle text, as a part of the height of the video.
    /// It is the default of the Android player.
    public static let normalTextFraction: Float = 0.0533

    /// The height of the subtitle text, as a part of the height of the video.
    public static func textFraction(_ size: Size) -> Float { normalTextFraction * size.scale }

    /// The box behind the subtitles: black with the opacity `alpha` from 0 to 255, as ARGB.
    public static func backgroundArgb(alpha: Int) -> UInt32 { UInt32(min(max(alpha, 0), 255)) << 24 }

    /// The colour of the edge around each letter, as ARGB.
    public static let edgeArgb: UInt32 = 0xFF00_0000
}
