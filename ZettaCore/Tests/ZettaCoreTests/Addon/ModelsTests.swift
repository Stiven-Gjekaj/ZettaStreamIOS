import Foundation
import Testing
@testable import ZettaCore

struct ModelsTests {
    private func json(_ text: String) throws -> JSONValue { try JSONValue.parse(Data(text.utf8)) }

    @Test func aPreviewReadsAYearThatIsANumber() throws {
        let preview = try #require(MetaPreview(json: json(#"{"id":"tt1","type":"series","name":"One","releaseInfo":2020,"unknown":true}"#)))
        #expect(preview.releaseInfo == "2020")
    }

    @Test func aPreviewWithNoTypeIsLeftOut() throws {
        #expect(MetaPreview(json: try json(#"{"id":"tt1"}"#)) == nil)
    }

    @Test func aMetaReadsTheEpisodes() throws {
        let meta = try #require(Meta(json: json(#"{"id":"tt1","type":"series","videos":[{"id":"tt1:1:1","title":"Pilot","season":"1","episode":1}]}"#)))
        #expect(meta.videos.single?.label == "Pilot")
        #expect(meta.videos.single?.season == 1)
    }

    @Test func anEpisodeWithNoTitleHasItsNumberAsTheLabel() {
        #expect(Video(id: "x:1:4", episode: 4).label == "Episode 4")
    }

    @Test func streamsKeepTheHeadersAndKnowWhatIsPlayable() throws {
        let hash = String(repeating: "a", count: 40)
        let http = AddonStream(json: try json(#"{"url":"https://cdn.test/a.m3u8","behaviorHints":{"proxyHeaders":{"request":{"Referer":"https://site.test/"}}}}"#))
        let torrent = AddonStream(json: try json(#"{"infoHash":"\#(hash)","fileIdx":2}"#))
        let short = AddonStream(json: try json(#"{"infoHash":"abc"}"#))
        let youtube = AddonStream(json: try json(#"{"ytId":"xyz"}"#))
        #expect(http.isPlayable(withTorrents: false))
        #expect(http.requestHeaders == ["Referer": "https://site.test/"])
        #expect(torrent.isTorrent)
        #expect(torrent.fileIdx == 2)
        #expect(!torrent.isPlayable(withTorrents: false))
        #expect(torrent.isPlayable(withTorrents: true))
        #expect(!short.isPlayable(withTorrents: true))
        #expect(!youtube.isPlayable(withTorrents: true))
    }

    @Test func theDetailsShowEachTextOneTime() {
        var stream = AddonStream(title: "Show.S01E01.1080p.mkv\n1.2 GB")
        stream.description = "1.2 GB"
        stream.hints.filename = "Show.S01E01.1080p.mkv"
        #expect(stream.details == "Show.S01E01.1080p.mkv\n1.2 GB")
    }
}

extension Array {
    var single: Element? { count == 1 ? first : nil }
}
