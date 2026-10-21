import Foundation

/// The newest release on GitHub.
public struct Release: Hashable, Sendable {
    /// The version, with no "v" before it, such as "0.2.0".
    public var version: String
    /// The page of the release, where the user gets the IPA.
    public var pageUrl: String

    public init(version: String, pageUrl: String) {
        self.version = version
        self.pageUrl = pageUrl
    }
}

/// Asks GitHub for the newest release. It sends no data about the user.
/// iOS does not let the app install an IPA, so the app gives the page of the release.
public struct UpdateChecker: Sendable {
    public static let latestApi = "https://api.github.com/repos/Stiven-Gjekaj/ZettaStreamIOS/releases/latest"
    public static let latestPage = "https://github.com/Stiven-Gjekaj/ZettaStreamIOS/releases/latest"

    private let session: URLSession
    private let userAgent: String
    private let apiUrl: String

    public init(session: URLSession = .shared, userAgent: String = ZettaCore.appName, apiUrl: String = UpdateChecker.latestApi) {
        self.session = session
        self.userAgent = userAgent
        self.apiUrl = apiUrl
    }

    /// The newest release, or nil for a fault. GitHub does not give a pre-release as
    /// the latest release, so a test version is not offered as an update.
    public func latest() async -> Release? {
        guard let address = URL(string: apiUrl) else { return nil }
        var request = URLRequest(url: address, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub refuses a request with no User-Agent.
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        guard let root = try? JSONValue.parse(data), let tag = root["tag_name"]?.stringValue else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let page = root["html_url"]?.stringValue.flatMap { $0.hasPrefix("https://") ? $0 : nil } ?? Self.latestPage
        return Release(version: version, pageUrl: page)
    }

    /// The newest release when it is newer than `current`, otherwise nil.
    public func update(from current: String) async -> Release? {
        guard let release = await latest(), Version.isNewer(release.version, than: current) else { return nil }
        return release
    }
}
