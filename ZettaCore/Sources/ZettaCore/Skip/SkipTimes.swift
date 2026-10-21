import Foundation

/// Gets the opening, ending, and recap times of an anime episode from AniSkip.
/// AniSkip knows MyAnimeList IDs, so the Kitsu ID goes through Kitsu first.
public actor SkipTimes {
    public static let kitsu = "https://kitsu.app/api/edge"
    public static let aniSkip = "https://api.aniskip.com/v2"

    private let session: URLSession
    private let userAgent: String
    private let kitsuBase: String
    private let aniSkipBase: String
    /// The MyAnimeList ID of each Kitsu ID, so that the next episode asks Kitsu no more.
    private var malIds: [Int: Int] = [:]

    public init(
        session: URLSession = .shared,
        userAgent: String = ZettaCore.appName,
        kitsuBase: String = SkipTimes.kitsu,
        aniSkipBase: String = SkipTimes.aniSkip
    ) {
        self.session = session
        self.userAgent = userAgent
        self.kitsuBase = kitsuBase
        self.aniSkipBase = aniSkipBase
    }

    /// The times for a video ID such as `kitsu:1376:5`. Another ID, a fault, or an
    /// unknown episode gives an empty list. The length of the video goes to AniSkip,
    /// so that it can match the times to this copy.
    public func forVideo(_ videoId: String, durationMs: Int) async -> [SkipRange] {
        guard let (kitsu, episode) = Skip.kitsuEpisode(videoId) else { return [] }
        let mal: Int
        if let known = malIds[kitsu] {
            mal = known
        } else {
            guard let data = await get("\(kitsuBase)/anime/\(kitsu)/mappings", accept: "application/vnd.api+json"),
                  let found = Skip.malIdFromKitsu(data) else { return [] }
            malIds[kitsu] = found
            mal = found
        }
        let seconds = max(durationMs / 1000, 0)
        // The brackets are percent-encoded, so that the URL is valid on each system.
        let types = ["op", "ed", "recap", "mixed-op", "mixed-ed"].map { "types%5B%5D=\($0)" }.joined(separator: "&")
        let url = "\(aniSkipBase)/skip-times/\(mal)/\(episode)?\(types)&episodeLength=\(seconds)"
        guard let data = await get(url, accept: "application/json") else { return [] }
        return Skip.parseAniSkip(data)
    }

    /// The body of a good answer, or nil for a fault or an error status.
    private func get(_ url: String, accept: String) async -> Data? {
        guard let address = URL(string: url) else { return nil }
        var request = URLRequest(url: address, timeoutInterval: 30)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return data
    }
}
