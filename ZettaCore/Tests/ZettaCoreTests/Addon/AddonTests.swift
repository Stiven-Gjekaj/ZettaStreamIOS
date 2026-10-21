import Testing
@testable import ZettaCore

struct AddonTests {
    private let addon = Addon(manifestUrl: "https://x.test/config%7Ckey/manifest.json", manifest: Manifest(id: "a", name: "A"))

    @Test func theBaseUrlKeepsTheConfigurationPath() {
        #expect(addon.baseUrl == "https://x.test/config%7Ckey")
    }

    @Test func aStremioLinkBecomesHttps() {
        #expect(Addon.normalizeManifestUrl(" stremio://x.test/manifest.json ") == "https://x.test/manifest.json")
    }

    @Test func theIdIsEncodedLikeEncodeUriComponent() {
        #expect(addon.resourceUrl("stream", type: "series", id: "tt0944947:1:2")
            == "https://x.test/config%7Ckey/stream/series/tt0944947%3A1%3A2.json")
    }

    @Test func extrasAreJoinedAndEncoded() {
        #expect(addon.resourceUrl("catalog", type: "movie", id: "top", extras: [("search", "the matrix"), ("skip", "100")])
            == "https://x.test/config%7Ckey/catalog/movie/top/search=the%20matrix&skip=100.json")
    }

    @Test func nonAsciiTextIsEncodedAsUtf8() {
        #expect(Addon.encodeComponent("été") == "%C3%A9t%C3%A9")
    }

    @Test func supportsChecksTheResourceTheTypeAndThePrefix() throws {
        let addon = Addon(manifestUrl: "https://x.test/manifest.json", manifest: try manifest("""
            {"id":"a","types":["movie","series"],"idPrefixes":["tt"],
             "resources":["meta",{"name":"stream","types":["series"],"idPrefixes":["kitsu:"]}]}
            """))
        #expect(addon.supports("meta", type: "movie", id: "tt1"))
        #expect(!addon.supports("meta", type: "movie", id: "kitsu:1"))
        #expect(addon.supports("stream", type: "series", id: "kitsu:1"))
        #expect(!addon.supports("stream", type: "movie", id: "kitsu:1"))
        #expect(!addon.supports("subtitles", type: "movie", id: "tt1"))
    }
}
