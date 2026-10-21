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

/// Gets profile pictures from free services that need no key: AniList for anime
/// characters, and TVmaze for the characters and the actors of TV shows.
/// When AniList gives no characters, Shikimori gives them.
/// A service that fails gives no pictures, and the other services still show.
public struct Avatars: Sendable {
    /// TVmaze IDs: Breaking Bad, Game of Thrones, Stranger Things, The Office, Friends, The Simpsons.
    public static let featuredShows = [169, 82, 2993, 526, 431, 83]

    /// The number of popular anime whose characters show when AniList gives none.
    public static let shikimoriAnime = 8
    /// The number of characters of each of those anime.
    public static let shikimoriRoles = 6
    /// The requests to Shikimori that go at the same time.
    static let shikimoriGroup = 4

    private let session: URLSession
    private let anilistUrl: String
    private let tvmazeUrl: String
    private let shikimoriUrl: String

    /// A test gives its own URLs for the services.
    public init(session: URLSession = .shared, anilistUrl: String = "https://graphql.anilist.co",
                tvmazeUrl: String = "https://api.tvmaze.com", shikimoriUrl: String = "https://shikimori.io") {
        self.session = session
        self.anilistUrl = anilistUrl
        self.tvmazeUrl = tvmazeUrl
        self.shikimoriUrl = shikimoriUrl
    }

    /// The most popular anime characters, and the characters of a few well-known shows.
    public func featured() async -> [AvatarGroup] {
        async let anime = animeFeatured()
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
        async let anime = animeSearch(q)
        async let people = Parse.tvmazePeople(get("\(tvmazeUrl)/search/people?q=\(Self.formEncode(q))"))
        return Self.groups(anime: await anime, tv: await people)
    }

    private static func groups(anime: [Avatar], tv: [Avatar]) -> [AvatarGroup] {
        [AvatarGroup(title: "Anime", avatars: anime), AvatarGroup(title: "TV and film", avatars: tv)].filter { !$0.avatars.isEmpty }
    }

    private func animeFeatured() async -> [Avatar] {
        let found = await anilist(nil)
        guard found.isEmpty else { return found }
        let popular = Parse.shikimoriAnime(await get("\(shikimoriUrl)/api/animes?order=popularity&limit=\(Self.shikimoriAnime)"))
        // Shikimori lets a client send 5 requests in each second, so the requests go in groups of 4.
        var casts = [[Avatar]](repeating: [], count: popular.count)
        for start in stride(from: 0, to: popular.count, by: Self.shikimoriGroup) {
            let ids = Array(popular[start..<min(start + Self.shikimoriGroup, popular.count)])
            await withTaskGroup(of: (Int, [Avatar]).self) { group in
                for (offset, id) in ids.enumerated() {
                    group.addTask {
                        // The index goes into a constant before the first await. See AddonRepository.install.
                        let index = start + offset
                        let roles = Parse.shikimoriRoles(await get("\(shikimoriUrl)/api/animes/\(id)/roles"), base: shikimoriUrl)
                        return (index, Array(roles.prefix(Self.shikimoriRoles)))
                    }
                }
                for await (index, cast) in group { casts[index] = cast }
            }
        }
        return Self.unique(casts.flatMap { $0 })
    }

    /// The characters whose name has `query`, and the characters of the anime whose title has it.
    private func animeSearch(_ query: String) async -> [Avatar] {
        let found = await anilist(query)
        guard found.isEmpty else { return found }
        let q = Self.formEncode(query)
        // The requests go one at a time, as in `animeFeatured`.
        let named = Parse.shikimoriCharacters(await get("\(shikimoriUrl)/api/characters/search?search=\(q)"), base: shikimoriUrl)
        let title = Parse.shikimoriAnime(await get("\(shikimoriUrl)/api/animes?search=\(q)&limit=1&order=popularity"))
        var cast: [Avatar] = []
        if let id = title.first {
            cast = Parse.shikimoriRoles(await get("\(shikimoriUrl)/api/animes/\(id)/roles"), base: shikimoriUrl)
        }
        return Self.unique(named + cast)
    }

    private static func unique(_ avatars: [Avatar]) -> [Avatar] {
        var seen = Set<String>()
        return avatars.filter { seen.insert($0.url).inserted }
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
        var request = URLRequest(url: address, timeoutInterval: 30)
        // Shikimori refuses a request with no name of the app.
        request.setValue("ZettaStream", forHTTPHeaderField: "User-Agent")
        return await load(request)
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

    /// Reads the answers of the services. A picture without a link is left out.
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

        /// The IDs of a list of anime.
        public static func shikimoriAnime(_ data: Data) -> [Int] {
            ((try? JSONValue.parse(data))?.arrayValue ?? []).compactMap { path($0, "id")?.intValue }
        }

        /// The characters of an anime: the main characters first, then the others.
        public static func shikimoriRoles(_ data: Data, base: String) -> [Avatar] {
            let roles = (try? JSONValue.parse(data))?.arrayValue ?? []
            let isMain: (JSONValue) -> Bool = { role in (path(role, "roles")?.arrayValue ?? []).contains { $0.stringValue == "Main" } }
            let ordered = roles.filter(isMain) + roles.filter { !isMain($0) }
            return ordered.compactMap { shikimoriAvatar(path($0, "character"), base: base) }
        }

        /// The answer of a search for characters.
        public static func shikimoriCharacters(_ data: Data, base: String) -> [Avatar] {
            ((try? JSONValue.parse(data))?.arrayValue ?? []).compactMap { shikimoriAvatar($0, base: base) }
        }

        /// A character with its picture. Shikimori gives a path, and a character with
        /// no picture has a path to a placeholder in `/assets/globals/`.
        private static func shikimoriAvatar(_ character: JSONValue?, base: String) -> Avatar? {
            guard let name = string(path(character, "name")), let image = string(path(character, "image", "original")),
                  !image.contains("/assets/globals/missing") else { return nil }
            return Avatar(name: name, url: image.hasPrefix("http") ? image : base + image)
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
