import Foundation

/// The request headers of a stream in the form that VLC reads. VLC sends a User-Agent,
/// a Referer, and cookies. It has no option for another header.
public struct VLCHeaderOptions: Hashable, Sendable {
    /// Media options such as `:http-user-agent=...`.
    public var options: [String]
    /// The cookies, each as `name=value`, for the cookie store of the media.
    public var cookies: [String]
    /// The names of the headers that VLC cannot send, in order.
    public var unsupported: [String]

    public init(options: [String] = [], cookies: [String] = [], unsupported: [String] = []) {
        self.options = options
        self.cookies = cookies
        self.unsupported = unsupported
    }
}

/// The options of VLC that the player sets.
public enum VLCOptions {
    /// Makes the media options of the headers. A header name has no case. With no User-Agent
    /// header, `userAgent` goes as the User-Agent.
    public static func headers(_ headers: [String: String], userAgent: String? = nil) -> VLCHeaderOptions {
        var out = VLCHeaderOptions()
        var agent = userAgent
        var referrer: String?
        for name in headers.keys.sorted(by: { $0.lowercased() < $1.lowercased() }) {
            let value = headers[name, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            switch name.lowercased() {
            case "user-agent": agent = value
            case "referer", "referrer": referrer = value
            case "cookie":
                out.cookies += value.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.contains("=") }
            default: out.unsupported.append(name)
            }
        }
        if let agent, !agent.isEmpty { out.options.append(":http-user-agent=\(agent)") }
        if let referrer, !referrer.isEmpty { out.options.append(":http-referrer=\(referrer)") }
        return out
    }

    /// The text renderer options of VLC for the subtitle look of the viewer. VLC reads them when
    /// the player starts, so a change starts the player again.
    public static func subtitles(_ settings: ViewerSettings) -> [String] {
        var options = [
            "--sub-text-scale=\(Int((settings.subtitleSize.scale * 100).rounded()))",
            "--freetype-color=\(settings.subtitleColor.argb & 0xFF_FFFF)",
            "--freetype-opacity=255",
            "--freetype-background-color=0",
            "--freetype-background-opacity=\(settings.subtitleBackground.alpha)",
            "--freetype-outline-color=0",
            "--freetype-shadow-color=0",
        ]
        switch settings.subtitleEdge {
        case .none:
            options += ["--freetype-outline-thickness=0", "--freetype-shadow-opacity=0"]
        case .outline:
            options += ["--freetype-outline-thickness=4", "--freetype-shadow-opacity=0"]
        case .shadow:
            options += ["--freetype-outline-thickness=0", "--freetype-shadow-opacity=192",
                        "--freetype-shadow-angle=-45", "--freetype-shadow-distance=0.06"]
        case .raised:
            // A thin edge and a short shadow up and to the left: the letters stand out of the picture.
            options += ["--freetype-outline-thickness=2", "--freetype-shadow-opacity=255",
                        "--freetype-shadow-angle=135", "--freetype-shadow-distance=0.03"]
        }
        switch settings.subtitleFont {
        case .default: break
        case .sans: options.append("--freetype-font=Helvetica")
        case .serif: options.append("--freetype-font=Georgia")
        case .mono: options.append("--freetype-font=Courier")
        case .bold: options.append("--freetype-bold")
        }
        return options
    }
}
