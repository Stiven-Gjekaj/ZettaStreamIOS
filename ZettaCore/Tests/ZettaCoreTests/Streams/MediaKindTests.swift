import Foundation
import Testing
@testable import ZettaCore

struct MediaKindTests {
    @Test func anHlsLinkInsideAProxyParameterIsHls() {
        #expect(MediaKind.from(url: "http://1.2.3.4/proxy/bound?d=https%3A%2F%2Fcdn.test%2Fhls2%2Findex.m3u8%3Ft%3D1") == .hls)
    }

    @Test func theEndingOfThePathDecides() {
        #expect(MediaKind.from(url: "https://cdn.test/a/master.m3u8?token=1") == .hls)
        #expect(MediaKind.from(url: "http://127.0.0.1:4000/abc/Big%20Buck%20Bunny.mp4") == .file)
        #expect(MediaKind.from(url: "https://cdn.test/a/,l,n,h,.urlset/master.txt") == nil)
        #expect(MediaKind.from(url: "https://cdn.test/v/manifest.mpd?token=1") == .dash)
        #expect(MediaKind.from(url: "https://cdn.test/v/master?format=mpd-time-csf") == .dash)
    }

    @Test func aBadEscapeKeepsTheLink() {
        #expect(MediaKind.from(url: "https://cdn.test/100%/video.MKV") == .file)
    }

    @Test func theAnswerDecidesWhenTheLinkDoesNotTell() {
        #expect(MediaKind.from(contentType: "application/vnd.apple.mpegurl", start: Data()) == .hls)
        #expect(MediaKind.from(contentType: "text/plain", start: Data("#EXTM3U\n#EXT-X-VERSION:3".utf8)) == .hls)
        #expect(MediaKind.from(contentType: "video/mp4", start: Data(count: 4)) == .file)
        #expect(MediaKind.from(contentType: "text/xml", start: Data(#"<?xml version="1.0"?><MPD xmlns="urn:mpeg:dash">"#.utf8)) == .dash)
        #expect(MediaKind.from(contentType: "text/html", start: Data("<html>".utf8)) == nil)
    }

    @Test func aByteOrderMarkAndSpacesBeforeThePlaylistDoNotMatter() {
        #expect(MediaKind.from(contentType: nil, start: Data("\u{FEFF}\r\n #EXTM3U".utf8)) == .hls)
    }
}
