import Foundation
import Testing
@testable import ZettaCore

struct BackupTests {
    private struct Device {
        let library: Library
        let settings: SettingsStore
        let sources: SourceStore
        var backup: Backup { Backup(library: library, settings: settings, sources: sources) }

        init() throws {
            let dir = try temporaryFolder()
            library = Library(file: dir.appendingPathComponent("library.json"))
            settings = SettingsStore(file: dir.appendingPathComponent("settings.json"))
            sources = SourceStore(file: dir.appendingPathComponent("sources.txt"))
        }
    }

    @Test func aBackupMovesTheLibraryTheSettingsAndTheSourcesToAnotherDevice() throws {
        let old = try Device()
        try old.library.toggleWatchlist(MetaPreview(id: "tt1", type: "movie", name: "One"))
        try old.library.toggleFavoriteChannel("news24al")
        try old.settings.update { $0.directFirst = true }
        try old.sources.replace("https://a.test/manifest.json")
        let file = try old.backup.export()

        let new = try Device()
        let report = try new.backup.restore(file)

        #expect(new.library.data.watchlist.map(\.id) == ["tt1"])
        #expect(new.library.data.favoriteChannels == ["news24al"])
        #expect(new.settings.settings.directFirst)
        #expect(new.sources.sources.map(\.url) == ["https://a.test/manifest.json"])
        #expect(report == "Restored 1 title in the watchlist, 0 videos in the history, and 1 source.")
    }

    @Test func anotherFileIsRefusedAndChangesNothing() throws {
        let device = try Device()
        try device.library.toggleWatchlist(MetaPreview(id: "tt1", type: "movie", name: "One"))
        for file in [#"{"app":"Other"}"#, "not json", "{}", "[]", #"{"library":{}}"#, #"{"app":"ZettaStream"}"#,
                     #"{"app":"ZettaStream","library":[]}"#, #"{"app":null,"library":{}}"#] {
            #expect(throws: (any Error).self, "\(file)") { try device.backup.restore(file) }
        }
        #expect(device.library.data.watchlist.map(\.id) == ["tt1"])
    }

    /// The text of an Android backup, with the keys of BackupData, LibraryData, Progress,
    /// MetaPreview, and ViewerSettings, and the names of the enum values.
    private let androidBackup = """
    {
        "app": "ZettaStream",
        "version": 1,
        "library": {
            "watchlist": [
                {
                    "id": "kitsu:1",
                    "type": "anime",
                    "name": "Cowboy Bebop",
                    "poster": "https://p.test/1.jpg",
                    "posterShape": null,
                    "background": null,
                    "logo": null,
                    "description": "Space.",
                    "releaseInfo": "1998",
                    "imdbRating": "8.9",
                    "genres": ["Action"],
                    "aliases": ["COWBOY BEBOP"],
                    "imdb_id": "tt0213338"
                }
            ],
            "progress": {
                "tt2:1:3": {
                    "videoId": "tt2:1:3",
                    "meta": {"id": "tt2", "type": "series", "name": "Two", "keyOfANewerVersion": true},
                    "label": "S1 E3",
                    "position": 600000,
                    "duration": 1800000,
                    "updated": 1760443200000
                }
            },
            "watched": ["tt2:1:1", "tt2:1:2"],
            "favoriteChannels": ["news24al"]
        },
        "settings": {
            "subtitlesOn": true,
            "subtitleLanguage": "sq",
            "audioLanguage": "ja",
            "subtitleSize": "Large",
            "subtitleColor": "Gray",
            "subtitleBackground": "Medium",
            "subtitleFont": "Mono",
            "subtitleEdge": "Shadow",
            "sideBars": "Stretch",
            "videoFilter": "BlackWhite",
            "autoplayNext": false,
            "autoSkipIntro": true,
            "matchFrameRate": false,
            "confirmChannel": false,
            "showTorrents": false,
            "directFirst": true,
            "torrentUpload": true,
            "vpnNotice": false,
            "audioDelayMs": 120,
            "searchHistory": ["frieren", "dragon"],
            "rowOrder": ["continue", "new"],
            "hiddenRows": ["live"]
        },
        "sources": "https://a.test/manifest.json\\nhttps://b.test/list.m3u"
    }
    """

    @Test func aBackupFromTheAndroidAppRestores() throws {
        let device = try Device()
        let report = try device.backup.restore(androidBackup)
        #expect(report == "Restored 1 title in the watchlist, 1 video in the history, and 2 sources.")

        let library = device.library.data
        let anime = try #require(library.watchlist.first)
        #expect(anime.imdbId == "tt0213338")
        #expect(anime.poster == "https://p.test/1.jpg")
        #expect(anime.genres == ["Action"] && anime.aliases == ["COWBOY BEBOP"])
        let entry = try #require(library.progress["tt2:1:3"])
        #expect(entry.meta.id == "tt2" && entry.label == "S1 E3")
        #expect(entry.position == 600_000 && entry.duration == 1_800_000 && entry.updated == 1_760_443_200_000)
        #expect(library.watched == ["tt2:1:1", "tt2:1:2"])
        #expect(library.favoriteChannels == ["news24al"])

        var expected = ViewerSettings()
        expected.subtitlesOn = true
        expected.subtitleLanguage = "sq"
        expected.audioLanguage = "ja"
        expected.subtitleSize = .large
        expected.subtitleColor = .gray
        expected.subtitleBackground = .medium
        expected.subtitleFont = .mono
        expected.subtitleEdge = .shadow
        expected.sideBars = .stretch
        expected.videoFilter = .blackWhite
        expected.autoplayNext = false
        expected.autoSkipIntro = true
        expected.matchFrameRate = false
        expected.confirmChannel = false
        expected.showTorrents = false
        expected.directFirst = true
        expected.torrentUpload = true
        expected.vpnNotice = false
        expected.audioDelayMs = 120
        expected.searchHistory = ["frieren", "dragon"]
        expected.rowOrder = ["continue", "new"]
        expected.hiddenRows = ["live"]
        #expect(device.settings.settings == expected)
        #expect(device.sources.sources.map(\.url) == ["https://a.test/manifest.json", "https://b.test/list.m3u"])
    }

    @Test func aBackupWithFewKeysTakesTheDefaultsAndKeepsTheSettingsAndTheSources() throws {
        let device = try Device()
        try device.settings.update { $0.directFirst = true }
        try device.sources.replace("https://a.test/manifest.json")
        try device.library.toggleWatchlist(MetaPreview(id: "tt1", type: "movie"))
        let text = #"{"app":"ZettaStream","library":{"watched":["a"]},"settings":null,"unknown":{"x":1}}"#
        let report = try device.backup.restore(text)
        #expect(device.library.data == LibraryData(watched: ["a"]))
        #expect(device.settings.settings.directFirst)
        #expect(device.sources.sources.count == 1)
        #expect(report == "Restored 0 titles in the watchlist, 0 videos in the history, and 0 sources.")
    }

    @Test func aBackupHasTheKeysOfTheAndroidBackup() throws {
        let device = try Device()
        var meta = MetaPreview(id: "kitsu:1", type: "anime", name: "One")
        meta.imdbId = "tt1"
        try device.library.toggleWatchlist(meta)
        try device.library.saveProgress(videoId: "kitsu:1:1", meta: meta, label: "E1", position: 10, duration: 100)
        try device.library.markWatched("kitsu:1:1")
        try device.library.toggleFavoriteChannel("news24al")
        try device.settings.update { $0.subtitleColor = .gray; $0.videoFilter = .blackWhite; $0.hiddenRows = ["live"] }
        try device.sources.replace("https://a.test/manifest.json")

        let root = try JSONValue.parse(Data(device.backup.export().utf8))
        #expect(Set(try #require(root.objectValue).keys) == ["app", "version", "library", "settings", "sources"])
        #expect(root["app"] == .string("ZettaStream"))
        #expect(root["version"] == .number(1))
        #expect(root["sources"] == .string("https://a.test/manifest.json"))

        let library = try #require(root["library"])
        #expect(Set(try #require(library.objectValue).keys) == ["watchlist", "progress", "watched", "favoriteChannels"])
        #expect(library["watched"] == .array([.string("kitsu:1:1")]))
        #expect(library["favoriteChannels"] == .array([.string("news24al")]))
        let preview = try #require(library["watchlist"]?.arrayValue?.first?.objectValue)
        #expect(Set(preview.keys) == ["id", "type", "name", "poster", "posterShape", "background", "logo", "description",
                                      "releaseInfo", "imdbRating", "genres", "aliases", "imdb_id"])
        #expect(preview["imdb_id"] == .string("tt1"))
        let entry = try #require(library["progress"]?["kitsu:1:1"]?.objectValue)
        #expect(Set(entry.keys) == ["videoId", "meta", "label", "position", "duration", "updated"])
        #expect(entry["position"] == .number(10))

        let settings = try #require(root["settings"]?.objectValue)
        #expect(Set(settings.keys) == [
            "subtitlesOn", "subtitleLanguage", "audioLanguage", "subtitleSize", "subtitleColor", "subtitleBackground",
            "subtitleFont", "subtitleEdge", "sideBars", "videoFilter", "autoplayNext", "autoSkipIntro", "matchFrameRate",
            "confirmChannel", "showTorrents", "directFirst", "torrentUpload", "vpnNotice", "audioDelayMs", "searchHistory",
            "rowOrder", "hiddenRows",
        ])
        #expect(settings["subtitleColor"] == .string("Gray"))
        #expect(settings["videoFilter"] == .string("BlackWhite"))
        #expect(settings["subtitleSize"] == .string("Normal"))
        #expect(settings["hiddenRows"] == .array([.string("live")]))
    }
}
