import Foundation

/// A picture that a profile can use, with the name of the character or the person.
public struct Avatar: Hashable, Sendable {
    public var name: String
    public var url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

/// The pictures of one service, with a title for the screen, such as "Anime".
public struct AvatarGroup: Hashable, Sendable {
    public var title: String
    public var avatars: [Avatar]

    public init(title: String, avatars: [Avatar]) {
        self.title = title
        self.avatars = avatars
    }
}

/// Gets profile pictures from two free services that need no key: AniList for anime
/// characters, and TVmaze for the characters and the actors of TV shows.
/// A service that fails gives no pictures, and the other service still shows.
public struct Avatars: Sendable {
    /// TVmaze IDs: Breaking Bad, Game of Thrones, Stranger Things, The Office, Friends, The Simpsons.
    public static let featuredShows = [169, 82, 2993, 526, 431, 83]

    private let session: URLSession
    private let anilistUrl: String
    private let tvmazeUrl: String

    /// A test gives its own URLs for the two services.
    public init(session: URLSession = .shared, anilistUrl: String = "https://graphql.anilist.co",
                tvmazeUrl: String = "https://api.tvmaze.com") {
        self.session = session
        self.anilistUrl = anilistUrl
        self.tvmazeUrl = tvmazeUrl
    }

    /// The most popular anime characters, and the characters of a few well-known shows.
    public func featured() async -> [AvatarGroup] {
        async let anime = anilist(nil)
        let tv = await withTaskGroup(of: (Int, [Avatar]).self) { group in
            for (index, id) in Self.featuredShows.enumerated() {
                group.addTask {
                    let position = index
                    return (position, await Parse.tvmazeCast(get("\(tvmazeUrl)/shows/\(id)/cast")))
                }
            }
            var casts: [(Int, [Avatar])] = []
            for await cast in group { casts.append(cast) }
            return casts.sorted { $0.0 < $1.0 }.flatMap(\.1)
        }
        return Self.groups(anime: await anime, tv: tv)
    }

    /// Anime characters and people of TV and film whose name has `query`.
    public func search(_ query: String) async -> [AvatarGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        async let anime = anilist(q)
        async let people = Parse.tvmazePeople(get("\(tvmazeUrl)/search/people?q=\(Self.formEncode(q))"))
        return Self.groups(anime: await anime, tv: await people)
    }

    private static func groups(anime: [Avatar], tv: [Avatar]) -> [AvatarGroup] {
        [AvatarGroup(title: "Anime", avatars: anime), AvatarGroup(title: "TV and film", avatars: tv)].filter { !$0.avatars.isEmpty }
    }

    private func anilist(_ search: String?) async -> [Avatar] {
        var body: [String: JSONValue]
        if let search {
            body = ["query": .string("query($s: String) { Page(perPage: 40) { characters(search: $s, sort: FAVOURITES_DESC) { name { full } image { large } } } }"),
                    "variables": .object(["s": .string(search)])]
        } else {
            body = ["query": .string("{ Page(perPage: 40) { characters(sort: FAVOURITES_DESC) { name { full } image { large } } } }")]
        }
        guard let url = URL(string: anilistUrl), let data = try? JSONEncoder().encode(JSONValue.object(body)) else { return [] }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return Parse.anilist(await load(request))
    }

    private func get(_ url: String) async -> Data {
        guard let address = URL(string: url) else { return Data() }
        return await load(URLRequest(url: address, timeoutInterval: 30))
    }

    /// The body of the answer. The status is not checked: an error answer has no pictures.
    private func load(_ request: URLRequest) async -> Data {
        (try? await session.data(for: request).0) ?? Data()
    }

    /// Encodes a text for a URL query as an HTML form does: a space becomes `+`.
    static func formEncode(_ text: String) -> String {
        var allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        allowed.insert(charactersIn: "-._* ")
        let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return encoded.replacingOccurrences(of: " ", with: "+")
    }

    /// Reads the answers of the two services. A picture without a link is left out.
    /// A text that is not JSON gives no pictures.
    public enum Parse {
        public static func anilist(_ data: Data) -> [Avatar] {
            let list = path(try? JSONValue.parse(data), "data", "Page", "characters")?.arrayValue ?? []
            return list.compactMap { c in
                guard let name = string(path(c, "name", "full")), let url = string(path(c, "image", "large")) else { return nil }
                return url.hasSuffix("/default.jpg") ? nil : Avatar(name: name, url: url)
            }
        }

        /// The characters of a cast, with the picture of the character, or else of the actor.
        public static func tvmazeCast(_ data: Data) -> [Avatar] {
            ((try? JSONValue.parse(data))?.arrayValue ?? []).compactMap { entry in
                let character = path(entry, "character")
                guard let name = string(path(character, "name")),
                      let url = string(path(character, "image", "medium")) ?? string(path(entry, "person", "image", "medium"))
                else { return nil }
                return Avatar(name: name, url: url)
            }
        }

        public static func tvmazePeople(_ data: Data) -> [Avatar] {
            ((try? JSONValue.parse(data))?.arrayValue ?? []).compactMap { entry in
                guard let name = string(path(entry, "person", "name")), let url = string(path(entry, "person", "image", "medium"))
                else { return nil }
                return Avatar(name: name, url: url)
            }
        }

        private static func path(_ value: JSONValue?, _ keys: String...) -> JSONValue? {
            keys.reduce(value) { at, key in at?[key] }
        }

        /// A text, a number, or a boolean that is not blank. An object, an array, or a null gives nil.
        private static func string(_ value: JSONValue?) -> String? {
            guard let text = value?.stringValue, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return text
        }
    }
}
