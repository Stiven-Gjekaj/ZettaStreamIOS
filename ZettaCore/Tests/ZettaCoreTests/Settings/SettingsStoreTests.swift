import Foundation
import Testing
@testable import ZettaCore

struct SettingsStoreTests {
    private let file: URL

    init() throws {
        file = try temporaryFolder().appendingPathComponent("settings.json")
    }

    private func write(_ text: String) throws {
        try Data(text.utf8).write(to: file)
    }

    @Test func aNewStoreHasTheDefaults() {
        let settings = SettingsStore(file: file).settings
        #expect(settings.showTorrents)
        #expect(!settings.torrentUpload)
        #expect(settings.vpnNotice)
        #expect(settings == ViewerSettings())
    }

    @Test func theDefaultsAreTheDefaultsOfTheAndroidApp() {
        let s = ViewerSettings()
        #expect(!s.subtitlesOn && s.subtitleLanguage == "en" && s.audioLanguage == "")
        #expect(s.subtitleSize == .normal && s.sideBars == .ambient && s.videoFilter == .none)
        #expect(s.autoplayNext && !s.autoSkipIntro && s.matchFrameRate && s.confirmChannel)
        #expect(!s.directFirst && s.audioDelayMs == 0)
        #expect(s.searchHistory.isEmpty && s.rowOrder.isEmpty && s.hiddenRows.isEmpty)
    }

    @Test func aChangeStaysAfterARestart() throws {
        try SettingsStore(file: file).update { $0.subtitlesOn = true; $0.subtitleSize = .large }
        let again = SettingsStore(file: file).settings
        #expect(again.subtitlesOn)
        #expect(again.subtitleSize == .large)
    }

    @Test func aFileFromAnOlderVersionKeepsItsValues() throws {
        try write(#"{"subtitlesOn":true,"removedKey":1}"#)
        let settings = SettingsStore(file: file).settings
        #expect(settings.subtitlesOn)
        #expect(settings.autoplayNext)
    }

    @Test func aRemovedChoiceBecomesTheDefaultAndTheOtherValuesStay() throws {
        try write(#"{"subtitlesOn":true,"sideBars":"Zoom","subtitleSize":"Large"}"#)
        let settings = SettingsStore(file: file).settings
        #expect(settings.sideBars == .ambient)
        #expect(settings.subtitlesOn)
        #expect(settings.subtitleSize == .large)
    }

    @Test func aNullBecomesTheDefault() throws {
        try write(#"{"subtitleLanguage":null,"vpnNotice":false}"#)
        let settings = SettingsStore(file: file).settings
        #expect(settings.subtitleLanguage == "en")
        #expect(!settings.vpnNotice)
    }

    @Test func aDamagedFileGivesTheDefaults() throws {
        try write("{not json")
        #expect(SettingsStore(file: file).settings == ViewerSettings())
    }

    @Test func nextGoesRoundTheOptions() {
        let options = SubtitleSize.allCases
        #expect(SettingsStore.next(options, .normal) == .large)
        #expect(SettingsStore.next(options, .huge) == .small)
        #expect(SettingsStore.next([SubtitleSize.large], .small) == .large)
    }

    @Test func aLanguageCodeGivesItsName() {
        #expect(SettingsStore.languageName("sq") == "Albanian")
        #expect(SettingsStore.languageName("") == "Original")
        #expect(SettingsStore.languageName("xx") == "xx")
    }

    @Test func anObserverSeesAChange() async throws {
        let store = SettingsStore(file: file)
        var updates = store.updates().makeAsyncIterator()
        #expect(await updates.next()?.directFirst == false)
        try store.update { $0.directFirst = true }
        #expect(await updates.next()?.directFirst == true)
    }
}
