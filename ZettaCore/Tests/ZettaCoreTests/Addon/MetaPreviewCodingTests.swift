import Foundation
import Testing
@testable import ZettaCore

struct MetaPreviewCodingTests {
    @Test func aPreviewReadsTheAndroidKeysAndAMissingKeyTakesTheDefault() throws {
        let text = #"{"id":"kitsu:1","type":"anime","imdb_id":"tt9","poster":null,"unknown":1}"#
        let preview = try JSONDecoder().decode(MetaPreview.self, from: Data(text.utf8))
        #expect(preview.imdbId == "tt9")
        #expect(preview.name == "")
        #expect(preview.genres == [])
        #expect(preview.poster == nil)
    }

    @Test func aPreviewWritesEachAndroidKeyAlsoANull() throws {
        var preview = MetaPreview(id: "tt1", type: "movie", name: "One")
        preview.imdbId = "tt1"
        let object = try #require(JSONValue.parse(JSONEncoder().encode(preview)).objectValue)
        #expect(Set(object.keys) == ["id", "type", "name", "poster", "posterShape", "background", "logo", "description",
                                     "releaseInfo", "imdbRating", "genres", "aliases", "imdb_id"])
        #expect(object["imdb_id"] == .string("tt1"))
        #expect(object["poster"] == .null)
    }

    @Test func aPreviewWithNoTypeIsNotRead() {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(MetaPreview.self, from: Data(#"{"id":"tt1"}"#.utf8)) }
    }
}
