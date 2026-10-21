import Testing
@testable import ZettaCore

struct VLCOptionsTests {
    @Test func theHeadersGoToTheOptionsOfVLC() {
        let out = VLCOptions.headers(
            ["referer": "https://site.example/", "User-Agent": "Box/1", "Cookie": "a=1; b=2 ;bad", "Origin": "https://site.example"],
            userAgent: "ZettaStream/1")
        #expect(out.options == [":http-user-agent=Box/1", ":http-referrer=https://site.example/"])
        #expect(out.cookies == ["a=1", "b=2"])
        #expect(out.unsupported == ["Origin"])
    }

    @Test func theAppAgentGoesWhenTheStreamHasNone() {
        #expect(VLCOptions.headers([:], userAgent: "ZettaStream/1").options == [":http-user-agent=ZettaStream/1"])
        #expect(VLCOptions.headers([:]) == VLCHeaderOptions())
        #expect(VLCOptions.headers(["Referrer": " "]).options.isEmpty)
    }

    @Test func theSubtitleLookGoesToTheTextRenderer() {
        var settings = ViewerSettings()
        settings.subtitleColor = .yellow
        settings.subtitleBackground = .solid
        settings.subtitleSize = .huge
        settings.subtitleFont = .mono
        let options = VLCOptions.subtitles(settings)
        #expect(options.contains("--freetype-color=\(0xFFE14D)"))
        #expect(options.contains("--freetype-background-opacity=255"))
        #expect(options.contains("--sub-text-scale=160"))
        #expect(options.contains("--freetype-font=Courier"))
        // The default edge is an outline with no shadow.
        #expect(options.contains("--freetype-outline-thickness=4"))
        #expect(options.contains("--freetype-shadow-opacity=0"))
    }

    @Test func eachEdgeGivesOtherOptions() {
        let edges = SubtitleEdge.allCases.map { edge in
            var settings = ViewerSettings()
            settings.subtitleEdge = edge
            return VLCOptions.subtitles(settings)
        }
        #expect(Set(edges).count == SubtitleEdge.allCases.count)
        var plain = ViewerSettings()
        plain.subtitleEdge = .none
        #expect(VLCOptions.subtitles(plain).contains("--freetype-outline-thickness=0"))
        #expect(!VLCOptions.subtitles(ViewerSettings()).contains { $0.hasPrefix("--freetype-font") || $0 == "--freetype-bold" })
    }
}
