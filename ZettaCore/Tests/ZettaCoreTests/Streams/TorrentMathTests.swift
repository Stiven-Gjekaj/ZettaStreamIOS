import Testing
@testable import ZettaCore

struct TorrentMathTests {
    @Test func theMagnetHoldsTheHashAndTheTrackersOfTheAddon() {
        let magnet = TorrentMath.magnet(
            infoHash: "ABCDEF0123456789ABCDEF0123456789ABCDEF01",
            sources: ["tracker:udp://a.test:80/announce", "dht:abcdef"],
            name: "Show S01E01"
        )
        #expect(magnet.hasPrefix("magnet:?xt=urn:btih:abcdef0123456789abcdef0123456789abcdef01&dn=Show+S01E01"))
        #expect(magnet.contains("&tr=udp%3A%2F%2Fa.test%3A80%2Fannounce"))
        #expect(!magnet.contains("dht"))
        #expect(magnet.contains("opentrackr"))
    }

    @Test func aBlankNameAndARepeatedTrackerAreLeftOut() {
        let magnet = TorrentMath.magnet(infoHash: "a", sources: ["tracker:" + TorrentMath.defaultTrackers[0]], name: "  ")
        #expect(!magnet.contains("&dn="))
        #expect(magnet.components(separatedBy: "&tr=").count == TorrentMath.defaultTrackers.count + 1)
    }

    @Test func aNameIsEncodedAsAForm() {
        #expect(TorrentMath.formEncode("a b/é*~") == "a+b%2F%C3%A9*%7E")
    }

    @Test func anInfoHashHasFortyHexCharacters() {
        #expect(TorrentMath.isInfoHash("abcdef0123456789ABCDEF0123456789abcdef01"))
        #expect(!TorrentMath.isInfoHash("xyz"))
        #expect(!TorrentMath.isInfoHash(nil))
        #expect(!TorrentMath.isInfoHash(String(repeating: "g", count: 40)))
    }

    @Test func theFileOfTheAddonComesFirstWhenItIsAVideo() {
        let names = ["Sample.mkv", "Show.S01E02.mkv", "Show.S01E01.mkv", "info.nfo"]
        let sizes: [Int64] = [50, 900, 1000, 1]
        #expect(TorrentMath.chooseFile(names: names, sizes: sizes, preferred: 1) == 1)
        #expect(TorrentMath.chooseFile(names: names, sizes: sizes, preferred: nil) == 2)
        #expect(TorrentMath.chooseFile(names: names, sizes: sizes, preferred: 3) == 2)
        #expect(TorrentMath.chooseFile(names: names, sizes: sizes, preferred: 99) == 2)
    }

    @Test func inASeasonPackTheFileNameOfTheAddonComesFirst() {
        let names = ["Pack/Show.S01E01.mkv", "Pack/Show.S01E02.mkv", "Pack/Show.S01E03.mkv"]
        let sizes: [Int64] = [900, 800, 1000]
        #expect(TorrentMath.chooseFile(names: names, sizes: sizes, preferred: nil, filename: "Show.S01E02.mkv") == 1)
    }

    @Test func inASeasonPackTheEpisodeNumberComesNext() {
        let names = ["Show.S01E01.mkv", "Show.S01E02.mkv", "Show.S01E12.mkv", "Show.S02E02.mkv"]
        let sizes: [Int64] = [900, 800, 1000, 1200]
        #expect(TorrentMath.chooseFile(names: names, sizes: sizes, preferred: nil, season: 1, episode: 2) == 1)
        let anime = ["[Group] Show - 01 [1080p].mkv", "[Group] Show - 05 [1080p].mkv", "[Group] Show - 15 [1080p].mkv"]
        #expect(TorrentMath.chooseFile(names: anime, sizes: [1, 1, 2], preferred: nil, episode: 5) == 1)
        #expect(TorrentMath.chooseFile(names: ["a.1x01.mp4", "a.1x02.mp4"], sizes: [5, 1], preferred: nil, season: 1, episode: 2) == 1)
    }

    @Test func withNoVideoTheLargestFileIsTheChoice() {
        #expect(TorrentMath.chooseFile(names: ["a.bin", "b.txt"], sizes: [10, 1], preferred: nil) == 0)
        #expect(TorrentMath.chooseFile(names: [], sizes: [], preferred: nil) == -1)
    }

    @Test func theFirstOfTwoEqualFilesWins() {
        #expect(TorrentMath.chooseFile(names: ["a.mkv", "b.mkv"], sizes: [7, 7], preferred: nil) == 0)
    }

    @Test func theMimeTypeComesFromTheExtension() {
        #expect(TorrentMath.mimeType("a.MKV") == "video/x-matroska")
        #expect(TorrentMath.mimeType("a.mp4") == "video/mp4")
        #expect(TorrentMath.mimeType("noext") == "application/octet-stream")
        #expect(!TorrentMath.isVideo("mkv"))
    }
}
