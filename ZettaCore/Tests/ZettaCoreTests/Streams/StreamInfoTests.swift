import Testing
@testable import ZettaCore

struct StreamInfoTests {
    @Test func readsTheSeedersInEachFormOfTheAddons() {
        #expect(StreamInfo.parse("Torrentio\n👤 304 💾 1.2 GB").seeders == 304)
        #expect(StreamInfo.parse("👥 15 seeders").seeders == 15)
        #expect(StreamInfo.parse("👤100:40").seeders == 100)
        #expect(StreamInfo.parse("Seeders: 12").seeders == 12)
        #expect(StreamInfo.parse("7 seeds").seeders == 7)
        #expect(StreamInfo.parse("1080p WEB-DL").seeders == nil)
    }

    @Test func readsTheQuality() {
        let info = StreamInfo.parse("[SubsPlease] Show - 05 (1080p) [HEVC] Dual Audio\n💾 1.45 GB")
        #expect(info.resolution == 1080)
        #expect(info.codec == "HEVC")
        #expect(info.dualAudio)
        #expect(info.sizeBytes == 1_450_000_000)
        #expect(info.group == "SubsPlease")
        #expect(StreamInfo.parse("Movie 4K HDR10 Remux").resolution == 2160)
        #expect(StreamInfo.parse("Movie 2160p HDR x265").hdr == "HDR")
        #expect(StreamInfo.parse("Movie 2160p DV").hdr == "Dolby Vision")
        #expect(StreamInfo.parse("Show.S01E01.720p.WEB-DL.x264").source == "WEB-DL")
        #expect(!StreamInfo.parse("Show 720p").dualAudio)
        // A file that ends in .ts is a transport stream, not a camera copy.
        #expect(StreamInfo.parse("Episode 5.ts").source == nil)
    }

    @Test func theHighestResolutionAndTheLargestSizeWin() {
        let info = StreamInfo.parse("Show 720p 1080p\n700 MB 1,5 GiB")
        #expect(info.resolution == 1080)
        #expect(info.sizeBytes == 1_610_612_736)
    }

    @Test func theGroupIsAtTheStartOfALine() {
        #expect(StreamInfo.parse("Torrentio\n[Erai-raws] Show - 01").group == "Erai-raws")
        #expect(StreamInfo.parse("Show [Erai-raws]").group == nil)
    }

    @Test func theBadgesAreShortAndInOrder() {
        let info = StreamInfo.parse("Movie 2160p HDR x265 BluRay 12.3 GB 👤 50")
        #expect(info.badges == ["4K", "HDR", "HEVC", "BluRay", "12.3 GB", "50 seeders"])
    }

    @Test func aSizeUnderOneGigabyteShowsInMegabytes() {
        #expect(StreamInfo.formatSize(734_003_200) == "734 MB")
        #expect(StreamInfo.formatSize(1_450_000_000) == "1.5 GB")
    }

    @Test func aSourceWithTheSameDataScoresHigher() {
        let current = StreamInfo.parse("[SubsPlease] Show - 05 (1080p) HEVC")
        let same = StreamInfo.parse("[SubsPlease] Show - 06 (1080p) HEVC")
        let other = StreamInfo.parse("[Other] Show - 06 (720p) x264 Dual Audio")
        #expect(StreamInfo.similarity(current, same) > StreamInfo.similarity(current, other))
    }

    @Test func theInfoOfAStreamReadsTheNameTheTitleAndTheFileName() {
        var stream = AddonStream(url: "https://a.test/1.mkv", name: "Server 👤 9", title: "Show.S01E01")
        stream.description = "HEVC"
        stream.hints.filename = "Show.S01E01.1080p.mkv"
        let info = StreamInfo(stream)
        #expect(info.seeders == 9)
        #expect(info.codec == "HEVC")
        #expect(info.resolution == 1080)
    }

    @Test func theDetailsHoldEachTextOneTime() {
        var stream = AddonStream(url: "https://a.test/1.mkv", title: "Show.S01E01.1080p.mkv\n1.4 GB")
        stream.description = "English subtitles"
        stream.hints.filename = "Show.S01E01.1080p.mkv"
        #expect(stream.details == "Show.S01E01.1080p.mkv\n1.4 GB\nEnglish subtitles")
    }
}
