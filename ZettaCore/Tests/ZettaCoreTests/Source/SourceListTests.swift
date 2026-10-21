import Testing
@testable import ZettaCore

struct SourceListTests {
    @Test func eachLineBecomesOneSourceOfTheCorrectKind() {
        let sources = SourceList.parse("""
              https://a.test/config/manifest.json
            stremio://b.test/manifest.json
            https://c.test/playlist.m3u
            https://c.test/list?type=m3u_plus
            https://d.test/guide.xml.gz
            https://d.test/epg/guide
            """)
        #expect(sources == [
            Source(url: "https://a.test/config/manifest.json", kind: .addon),
            Source(url: "https://b.test/manifest.json", kind: .addon),
            Source(url: "https://c.test/playlist.m3u", kind: .playlist),
            Source(url: "https://c.test/list?type=m3u_plus", kind: .playlist),
            Source(url: "https://d.test/guide.xml.gz", kind: .guide),
            Source(url: "https://d.test/epg/guide", kind: .guide),
        ])
    }

    @Test func blankLinesCommentsTextAndDuplicatesAreIgnored() {
        let sources = SourceList.parse("\n# my list\nnot a url\r\nhttps://a.test/manifest.json\r\nhttps://a.test/manifest.json\n")
        #expect(sources == [Source(url: "https://a.test/manifest.json", kind: .addon)])
    }

    @Test func formatWritesOneUrlOnEachLine() {
        let text = "https://a.test/manifest.json\nhttps://c.test/p.m3u"
        #expect(SourceList.format(SourceList.parse(text)) == text)
    }
}
