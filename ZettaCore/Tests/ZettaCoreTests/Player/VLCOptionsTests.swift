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
}
