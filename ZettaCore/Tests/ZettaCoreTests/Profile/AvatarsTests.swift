import Foundation
import Testing
@testable import ZettaCore

struct AvatarsTests {
    private let anilist = StubServer()
    private let tvmaze = StubServer()
    private let shikimori = StubServer()
    private var avatars: Avatars {
        Avatars(session: anilist.session, anilistUrl: anilist.url("/"), tvmazeUrl: tvmaze.url(""), shikimoriUrl: shikimori.url(""))
    }

    private func data(_ text: String) -> Data { Data(text.utf8) }

    /// The body of a request. URLSession can give it to the stub as a stream.
    private func body(_ request: URLRequest?) -> JSONValue? {
        if let body = request?.httpBody { return try? JSONValue.parse(body) }
        guard let stream = request?.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var bytes = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            bytes.append(buffer, count: count)
        }
        return try? JSONValue.parse(bytes)
    }

    @Test func readsAniListCharactersAndLeavesOutTheDefaultPicture() {
        let text = """
            {"data":{"Page":{"characters":[
            {"name":{"full":"Satoru Gojou"},"image":{"large":"https://s4.anilist.co/c/large/b1.png"}},
            {"name":{"full":"Nobody"},"image":{"large":"https://s4.anilist.co/c/large/default.jpg"}},
            {"name":{"full":"No picture"},"image":{"large":null}}]}}}
            """
        #expect(Avatars.Parse.anilist(data(text)) == [Avatar(name: "Satoru Gojou", url: "https://s4.anilist.co/c/large/b1.png")])
        #expect(Avatars.Parse.anilist(data(#"{"errors":[{"message":"Too Many Requests"}]}"#)) == [])
        #expect(Avatars.Parse.anilist(data("not json")) == [])
    }

    @Test func aCastUsesTheCharacterPictureOrElseTheActor() {
        let text = """
            [
            {"person":{"name":"Bryan Cranston","image":{"medium":"https://t.test/p1.jpg"}},"character":{"name":"Walter White","image":{"medium":"https://t.test/c1.jpg"}}},
            {"person":{"name":"Aaron Paul","image":{"medium":"https://t.test/p2.jpg"}},"character":{"name":"Jesse Pinkman","image":null}},
            {"person":{"name":"X","image":null},"character":{"name":"Y","image":null}}]
            """
        #expect(Avatars.Parse.tvmazeCast(data(text)) == [
            Avatar(name: "Walter White", url: "https://t.test/c1.jpg"),
            Avatar(name: "Jesse Pinkman", url: "https://t.test/p2.jpg"),
        ])
    }

    @Test func readsPeopleFromASearch() {
        let text = #"[{"score":1,"person":{"name":"Morgan Freeman","image":{"medium":"https://t.test/m.jpg"}}},{"score":0.5,"person":{"name":"Other","image":null}}]"#
        #expect(Avatars.Parse.tvmazePeople(data(text)) == [Avatar(name: "Morgan Freeman", url: "https://t.test/m.jpg")])
    }

    @Test func aBlankNameIsLeftOut() {
        let text = #"[{"person":{"name":"  ","image":{"medium":"https://t.test/m.jpg"}}}]"#
        #expect(Avatars.Parse.tvmazePeople(data(text)) == [])
    }

    @Test func aSearchAsksBothServicesWithTheName() async throws {
        anilist.reply(#"{"data":{"Page":{"characters":[{"name":{"full":"Frieren"},"image":{"large":"https://a.test/f.png"}}]}}}"#)
        tvmaze.reply(#"[{"person":{"name":"Anne Hathaway","image":{"medium":"https://t.test/a.jpg"}}}]"#)
        let groups = await avatars.search("  Anne & Frieren ")
        #expect(groups == [
            AvatarGroup(title: "Anime", avatars: [Avatar(name: "Frieren", url: "https://a.test/f.png")]),
            AvatarGroup(title: "TV and film", avatars: [Avatar(name: "Anne Hathaway", url: "https://t.test/a.jpg")]),
        ])
        #expect(tvmaze.lastRequest?.url?.absoluteString == tvmaze.url("/search/people?q=Anne+%26+Frieren"))
        let request = try #require(anilist.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let sent = try #require(body(request))
        #expect(sent["variables"]?["s"] == .string("Anne & Frieren"))
        #expect(sent["query"]?.stringValue?.contains("characters(search: $s, sort: FAVOURITES_DESC)") == true)
    }

    @Test func aServiceThatFailsLeavesOnlyTheOther() async {
        anilist.reply("Too Many Requests", status: 429)
        tvmaze.reply(#"[{"person":{"name":"Anne Hathaway","image":{"medium":"https://t.test/a.jpg"}}}]"#)
        #expect(await avatars.search("anne").map(\.title) == ["TV and film"])
    }

    @Test func theFeaturedPicturesComeFromTheTopCharactersAndTheCastOfEachShow() async throws {
        anilist.reply(#"{"data":{"Page":{"characters":[{"name":{"full":"Gojou"},"image":{"large":"https://a.test/g.png"}}]}}}"#)
        for _ in Avatars.featuredShows {
            tvmaze.reply(#"[{"person":{"name":"P","image":null},"character":{"name":"C","image":{"medium":"https://t.test/c.jpg"}}}]"#)
        }
        let groups = await avatars.featured()
        #expect(groups.map(\.title) == ["Anime", "TV and film"])
        #expect(groups.last?.avatars.count == Avatars.featuredShows.count)
        #expect(Set(tvmaze.paths) == Set(Avatars.featuredShows.map { "/shows/\($0)/cast" }))
        let sent = try #require(body(anilist.lastRequest))
        #expect(sent["variables"] == nil)
    }

    private func role(_ name: String, _ id: Int, main: Bool = false, image: String? = nil) -> String {
        let picture = image ?? "/system/characters/original/\(id).jpg?1"
        return #"{"roles":["\#(main ? "Main" : "Supporting")"],"character":{"name":"\#(name)","image":{"original":"\#(picture)"}},"person":null}"#
    }

    @Test func shikimoriRolesPutTheMainCharactersFirstAndLeaveOutThePlaceholder() {
        let text = "[" + [
            role("Side", 1),
            role("Hero", 2, main: true),
            role("Nobody", 3, image: "/assets/globals/missing_original.jpg"),
            #"{"roles":["Main"],"character":null,"person":{"name":"Voice"}}"#,
        ].joined(separator: ",") + "]"
        #expect(Avatars.Parse.shikimoriRoles(data(text), base: "https://s.test") == [
            Avatar(name: "Hero", url: "https://s.test/system/characters/original/2.jpg?1"),
            Avatar(name: "Side", url: "https://s.test/system/characters/original/1.jpg?1"),
        ])
        #expect(Avatars.Parse.shikimoriRoles(data("not json"), base: "https://s.test") == [])
    }

    @Test func whenAniListFailsTheFeaturedAnimeComeFromShikimori() async {
        anilist.reply("disabled", status: 403)
        for _ in Avatars.featuredShows { tvmaze.reply("[]") }
        shikimori.reply(#"[{"id":10,"name":"A"},{"id":20,"name":"B"}]"#)
        shikimori.reply("[" + (1...8).map { role("A\($0)", $0, main: $0 == 8) }.joined(separator: ",") + "]")
        shikimori.reply("[" + role("B1", 1) + "," + role("B9", 9) + "]")
        let groups = await avatars.featured()
        let names = groups.first?.avatars.map(\.name) ?? []
        #expect(groups.map(\.title) == ["Anime"])
        // Each anime gives its first characters, main first. "B1" has the picture of "A1", so it is left out.
        #expect(names == ["A8", "A1", "A2", "A3", "A4", "A5", "B9"])
        #expect(shikimori.paths == ["/api/animes", "/api/animes/10/roles", "/api/animes/20/roles"])
        #expect(shikimori.lastRequest?.value(forHTTPHeaderField: "User-Agent") == "ZettaStream")
    }

    @Test func whenAniListFailsASearchFindsNamesAndTheCastOfTheTitle() async {
        anilist.reply("disabled", status: 403)
        tvmaze.reply("[]")
        shikimori.reply(#"[{"id":1,"name":"Frieren","image":{"original":"/system/characters/original/1.jpg?1"}}]"#)
        shikimori.reply(#"[{"id":52991,"name":"Sousou no Frieren"}]"#)
        shikimori.reply("[" + role("Fern", 2, main: true) + "," + role("Frieren", 1, main: true) + "]")
        let names = await avatars.search("frieren").first?.avatars.map(\.name)
        #expect(names == ["Frieren", "Fern"])
        #expect(shikimori.paths == ["/api/characters/search", "/api/animes", "/api/animes/52991/roles"])
    }

    @Test func aWorkingAniListDoesNotAskShikimori() async {
        anilist.reply(#"{"data":{"Page":{"characters":[{"name":{"full":"Frieren"},"image":{"large":"https://a.test/f.png"}}]}}}"#)
        tvmaze.reply("[]")
        #expect(await avatars.search("frieren").first?.avatars.count == 1)
        #expect(shikimori.paths.isEmpty)
    }
}
