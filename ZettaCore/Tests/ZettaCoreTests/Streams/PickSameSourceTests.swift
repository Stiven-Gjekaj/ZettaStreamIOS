import Testing
@testable import ZettaCore

struct PickSameSourceTests {
    private func stream(_ url: String, _ name: String? = nil, _ group: String? = nil, title: String? = nil) -> AddonStream {
        var stream = AddonStream(url: url, name: name, title: title)
        stream.hints.bingeGroup = group
        return stream
    }

    private var streams: [AddonStream] {
        [
            stream("https://a/1", "Server A 720p", "a-720"),
            stream("https://b/1", "Server B 1080p", "b-1080"),
            stream("https://c/1", "Server C 1080p"),
        ]
    }

    @Test func theBingeGroupComesFirst() {
        #expect(StreamOrder.pickSameSource(streams, bingeGroup: "b-1080", streamName: "Server A 720p")?.url == "https://b/1")
    }

    @Test func withNoBingeGroupTheSameNameIsTheMatch() {
        #expect(StreamOrder.pickSameSource(streams, bingeGroup: nil, streamName: "Server C 1080p")?.url == "https://c/1")
    }

    @Test func withNoMatchTheFirstStreamIsTheChoice() {
        #expect(StreamOrder.pickSameSource(streams, bingeGroup: "gone", streamName: "gone")?.url == "https://a/1")
        #expect(StreamOrder.pickSameSource([], bingeGroup: "a-720", streamName: nil) == nil)
    }

    @Test func theDataMattersMoreThanTheName() {
        let next = [
            stream("https://x/720", "Server A", title: "[Group] Show - 06 (720p) x264"),
            stream("https://x/1080", "Server B", title: "[SubsPlease] Show - 06 (1080p) HEVC"),
        ]
        let current = StreamInfo.parse("[SubsPlease] Show - 05 (1080p) HEVC")
        #expect(StreamOrder.pickSameSource(next, bingeGroup: nil, streamName: "Server A", current: current)?.url == "https://x/1080")
    }

    @Test func theBingeGroupStillComesFirst() {
        let next = [
            stream("https://x/1080", "B", "other", title: "Show 1080p HEVC"),
            stream("https://x/720", "A", "mine", title: "Show 720p"),
        ]
        let current = StreamInfo.parse("Show 1080p HEVC")
        #expect(StreamOrder.pickSameSource(next, bingeGroup: "mine", streamName: nil, current: current)?.url == "https://x/720")
    }

    @Test func theSameKindBreaksATie() {
        let next = [
            stream("https://x/1", "A"),
            AddonStream(infoHash: String(repeating: "e", count: 40), name: "B"),
        ]
        #expect(StreamOrder.pickSameSource(next, bingeGroup: nil, streamName: nil, wasTorrent: true)?.name == "B")
        #expect(StreamOrder.pickSameSource(next, bingeGroup: nil, streamName: nil, wasTorrent: false)?.name == "A")
    }
}
