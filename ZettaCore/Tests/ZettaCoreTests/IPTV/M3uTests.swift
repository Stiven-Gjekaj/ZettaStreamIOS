import Testing
@testable import ZettaCore

struct M3uTests {
    @Test func readsTheChannelAttributesAndTheGuideUrls() throws {
        let playlist = M3u.parse("""
            #EXTM3U x-tvg-url="https://g.test/a.xml, https://g.test/b.xml.gz"
            #EXTINF:-1 tvg-id="news.test" tvg-logo="https://l.test/n.png" group-title="News",News One
            https://s.test/news.m3u8
            #EXTINF:-1,Plain
            http://s.test/plain.ts
            """)
        #expect(playlist.guideUrls == ["https://g.test/a.xml", "https://g.test/b.xml.gz"])
        try #require(playlist.channels.count == 2)
        let news = playlist.channels[0]
        let plain = playlist.channels[1]
        #expect(news.name == "News One")
        #expect(news.tvgId == "news.test")
        #expect(news.group == "News")
        #expect(news.logo == "https://l.test/n.png")
        #expect(plain.url == "http://s.test/plain.ts")
        #expect(plain.group == nil)
        #expect(plain.key == "http://s.test/plain.ts")
    }

    @Test func readsHeadersFromVlcOptionsJsonAndThePipeForm() throws {
        let playlist = M3u.parse("""
            #EXTM3U
            #EXTINF:-1,One
            #EXTVLCOPT:http-user-agent=Agent/1
            #EXTVLCOPT:http-referrer=https://r.test/
            https://s.test/1.m3u8
            #EXTINF:-1,Two
            #EXTHTTP:{"Origin":"https://o.test"}
            https://s.test/2.m3u8|User-Agent=Agent%2F2&Referer=https://r2.test/
            """)
        try #require(playlist.channels.count == 2)
        #expect(playlist.channels[0].headers == ["User-Agent": "Agent/1", "Referer": "https://r.test/"])
        #expect(playlist.channels[1].url == "https://s.test/2.m3u8")
        #expect(playlist.channels[1].headers == ["Origin": "https://o.test", "User-Agent": "Agent/2", "Referer": "https://r2.test/"])
    }

    @Test func theHeadersOfOneChannelDoNotGoToTheNext() throws {
        let playlist = M3u.parse("#EXTM3U\n#EXTINF:-1,A\n#EXTVLCOPT:http-user-agent=X\nhttps://a\n#EXTINF:-1,B\nhttps://b")
        try #require(playlist.channels.count == 2)
        #expect(playlist.channels[1].headers == [:])
    }

    @Test func aCommaInTheAttributesDoesNotBreakTheName() throws {
        let playlist = M3u.parse("#EXTM3U\n#EXTINF:-1 group-title=\"A, B\",Name, with comma\nhttps://a")
        try #require(playlist.channels.count == 1)
        #expect(playlist.channels[0].group == "A, B")
        #expect(playlist.channels[0].name == "Name, with comma")
    }

    @Test func copiesWithOneIdAreFavouritesAlone() {
        let channels = [
            Channel(name: "News HD", url: "https://s.test/hd.m3u8", tvgId: "news.al"),
            Channel(name: "News SD", url: "https://s.test/sd.m3u8", tvgId: "news.al"),
            Channel(name: "Music", url: "https://s.test/music.m3u8", tvgId: "music.al"),
            Channel(name: "Plain", url: "https://s.test/plain.m3u8"),
        ]
        #expect(Channel.favoriteKeys(channels) == [
            "https://s.test/hd.m3u8": "https://s.test/hd.m3u8",
            "https://s.test/sd.m3u8": "https://s.test/sd.m3u8",
            "https://s.test/music.m3u8": "music.al",
            "https://s.test/plain.m3u8": "https://s.test/plain.m3u8",
        ])
    }

    // The tests below are not in the Android app. They hold the edge cases of the Kotlin code.

    @Test func windowsLineEndsAndTheOldGuideAttributeAlsoWork() throws {
        let playlist = M3u.parse("#EXTM3U url-tvg=\"https://g.test/c.xml\"\r\n#EXTINF:-1 tvg-name=\"Named\" tvg-id=\" \"\r\nhttps://c\r\n")
        #expect(playlist.guideUrls == ["https://g.test/c.xml"])
        try #require(playlist.channels.count == 1)
        #expect(playlist.channels[0].name == "Named")
        #expect(playlist.channels[0].tvgId == nil)
        #expect(playlist.channels[0].key == "https://c")
    }

    @Test func aChannelWithNoNameUsesItsLink() throws {
        let playlist = M3u.parse("#EXTM3U\n#EXTINF:-1 tvg-id=\"x\",  \n# a comment\nhttps://x")
        try #require(playlist.channels.count == 1)
        #expect(playlist.channels[0].name == "https://x")
        #expect(playlist.channels[0].key == "x")
    }

    @Test func thePipeFormWinsOverAVlcOptionAndAPlusIsASpace() throws {
        let playlist = M3u.parse("#EXTINF:-1,A\n#EXTVLCOPT:http-user-agent=Old\nhttps://a|User-Agent=New+One&broken&=x")
        try #require(playlist.channels.count == 1)
        #expect(playlist.channels[0].headers == ["User-Agent": "New One"])
    }
}
