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

    @Test func rangesReadEachForm() {
        #expect(TorrentMath.range(header: nil, size: 1000) == 0..<1000)
        #expect(TorrentMath.range(header: "bytes=100-", size: 1000) == 100..<1000)
        #expect(TorrentMath.range(header: "bytes=100-199", size: 1000) == 100..<200)
        #expect(TorrentMath.range(header: "bytes=-100", size: 1000) == 900..<1000)
        #expect(TorrentMath.range(header: "bytes=990-5000", size: 1000) == 990..<1000)
        #expect(TorrentMath.range(header: "bytes=1000-", size: 1000) == nil)
        #expect(TorrentMath.range(header: "bytes=500-100", size: 1000) == nil)
    }

    @Test func aRangeUsesOnlyItsFirstPart() {
        #expect(TorrentMath.range(header: "bytes= 0-9 , 20-29", size: 1000) == 0..<10)
        #expect(TorrentMath.range(header: "items=0-9", size: 1000) == 0..<1000)
        #expect(TorrentMath.range(header: "bytes=-5000", size: 1000) == 0..<1000)
        #expect(TorrentMath.range(header: "bytes=a-", size: 1000) == nil)
        #expect(TorrentMath.range(header: nil, size: 0) == nil)
    }

    @Test func onlyTheHeadTheTailAndTheWindowAreWanted() {
        let wanted = TorrentMath.wanted(firstPiece: 10, lastPiece: 109, readPiece: 50, aheadPieces: 5, edgePieces: 2)
        #expect(wanted == [10, 11, 108, 109, 50, 51, 52, 53, 54, 55])
    }

    @Test func theWindowStopsAtTheEndOfTheFile() {
        #expect(TorrentMath.wanted(firstPiece: 0, lastPiece: 9, readPiece: 8, aheadPieces: 5, edgePieces: 1) == [0, 8, 9])
        #expect(TorrentMath.wanted(firstPiece: 0, lastPiece: 3, readPiece: 0, aheadPieces: 10, edgePieces: 1) == [0, 1, 2, 3])
    }

    @Test func noEdgeAndAnEmptyFileWantLittle() {
        #expect(TorrentMath.wanted(firstPiece: 0, lastPiece: 9, readPiece: 4, aheadPieces: 1, edgePieces: 0) == [4, 5])
        #expect(TorrentMath.wanted(firstPiece: 5, lastPiece: 4, readPiece: 4, aheadPieces: 1, edgePieces: 1).isEmpty)
    }

    @Test func onlyThePiecesAfterTheReadPositionAreNeededNow() {
        let levels = TorrentMath.priorities(numPieces: 100, firstPiece: 0, lastPiece: 99, readPiece: 40, nowPieces: 3, aheadPieces: 10, edgePieces: 2)
        #expect(levels.indices.filter { levels[$0] == TorrentMath.priorityNow } == [40, 41, 42])
        #expect(levels.indices.filter { levels[$0] == TorrentMath.priorityLater } == [0, 1] + Array(43...50) + [98, 99])
        #expect(levels[60] == 0)
    }

    @Test func theWindowFollowsTheSizeOfTheFile() {
        let mb: Int64 = 1024 * 1024
        #expect(TorrentMath.windowBytes(fileSize: 300 * mb) == 24 * mb)
        #expect(TorrentMath.windowBytes(fileSize: 1_626_000_000) == 1_626_000_000 / 30)
        #expect(TorrentMath.windowBytes(fileSize: 20_000 * mb) == 96 * mb)
    }

    @Test func piecesForRoundsUp() {
        #expect(TorrentMath.piecesFor(bytes: 2_500_000, pieceLength: 1_000_000) == 3)
        #expect(TorrentMath.piecesFor(bytes: 0, pieceLength: 1_000_000) == 1)
    }

    @Test func theMimeTypeComesFromTheExtension() {
        #expect(TorrentMath.mimeType("a.MKV") == "video/x-matroska")
        #expect(TorrentMath.mimeType("a.mp4") == "video/mp4")
        #expect(TorrentMath.mimeType("noext") == "application/octet-stream")
        #expect(!TorrentMath.isVideo("mkv"))
    }

    @Test func theStatusShowsThePeersTheSpeedAndTheFile() {
        #expect(TorrentMath.status(peers: 12, downloadRate: 1_440_000, fileDone: 180_000_000, fileSize: 1_500_000_000)
            == "Torrent: 12 peers, 1.4 MB/s, 180 MB of 1.5 GB")
        #expect(TorrentMath.status(peers: 0, downloadRate: 0, fileDone: 0, fileSize: 0) == "Torrent: 0 peers, 0.0 MB/s, 0 MB of 0 MB")
    }
}
