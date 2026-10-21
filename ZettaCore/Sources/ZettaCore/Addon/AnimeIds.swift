import Foundation

/// The IDs of anime in other databases.
///
/// An addon such as AnimeStream gives a new anime a MyAnimeList ID, such as
/// `mal-61987:1:3`, before IMDb knows the anime. No stream addon reads that
/// form, but many read the Kitsu form, such as `kitsu:50021:3`. Kitsu keeps
/// one entry for each season, so its form has no season number.
public enum AnimeIds {
    /// The MyAnimeList number and the episode of a video ID such as
    /// `mal-61987:1:3`, or `mal-61987` for a film. Nil for another kind of ID.
    public static func mal(_ videoId: String) -> (id: Int, episode: Int?)? {
        let parts = videoId.split(separator: ":", omittingEmptySubsequences: false)
        guard let first = parts.first, first.hasPrefix("mal-"), let id = Int(first.dropFirst(4)) else { return nil }
        return (id, parts.count >= 3 ? Int(parts[parts.count - 1]) : parts.count == 2 ? Int(parts[1]) : nil)
    }

    /// The Kitsu form of a video, such as `kitsu:50021:3`, or `kitsu:50021` with no episode.
    public static func kitsuVideoId(kitsu: Int, episode: Int?) -> String {
        episode.map { "kitsu:\(kitsu):\($0)" } ?? "kitsu:\(kitsu)"
    }

    /// Reads the Kitsu number from an answer of the mappings of Kitsu.
    static func kitsuId(mappingAnswer data: Data) -> Int? {
        let root = try? JSONValue.parse(data)
        let included = root?["included"]?.arrayValue ?? []
        let anime = included.first { $0["type"]?.stringValue == "anime" }
        return anime?["id"]?.intValue
    }
}

/// Finds the Kitsu number of a MyAnimeList number, and keeps each answer in memory.
/// With a file, each number that it finds also stays on the disk for the next start.
public actor KitsuMapper {
    public static let api = "https://kitsu.io/api/edge"

    private let session: URLSession
    private let base: String
    private var known: [Int: Int?] = [:]
    private let saved: JSONFile<[String: Int]>?

    /// A test gives its own address for Kitsu.
    public init(session: URLSession = .shared, base: String = KitsuMapper.api, file: URL? = nil) {
        self.session = session
        self.base = base
        saved = file.map { JSONFile(file: $0) { [:] } }
        for (mal, kitsu) in saved?.value ?? [:] {
            if let mal = Int(mal) { known[mal] = kitsu }
        }
    }

    /// The Kitsu number, or nil when Kitsu does not know the anime or does not answer.
    /// A failed request is not kept, so a later call asks again.
    public func kitsuId(mal: Int) async -> Int? {
        if let found = known[mal] { return found }
        let query = "filter%5BexternalSite%5D=myanimelist%2Fanime&filter%5BexternalId%5D=\(mal)&include=item"
        guard let url = URL(string: "\(base)/mappings?\(query)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let found = AnimeIds.kitsuId(mappingAnswer: data)
        known[mal] = found
        // A number that Kitsu does not know is asked again at the next start, because Kitsu can add it.
        if let found { try? saved?.update { $0[String(mal)] = found } }
        return found
    }
}
