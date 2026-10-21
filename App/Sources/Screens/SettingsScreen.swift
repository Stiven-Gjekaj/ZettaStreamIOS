import SwiftUI
import ZettaCore

/// The settings of the current profile, and the entries to the sources, the profiles, and the home rows.
struct SettingsScreen: View {
    @EnvironmentObject private var app: AppModel
    @State private var confirmClear = false
    @State private var backupFile: SettingsBackupFile?
    @State private var exporting = false
    @State private var importing = false
    @State private var restoreReport: String?

    private var viewer: ViewerSettings { app.settings }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                SettingsPageTitle(text: "Settings")
                entries
                viewing
                torrents
                SettingsSection(title: "App")
                backup
                SettingsRow(title: "Clear the watch history", detail: "Removes the progress of each video. The watchlist stays.") {
                    confirmClear = true
                }
            }
            .padding(.vertical, 16)
        }
        .zettaScreen()
        .toolbar(.hidden, for: .navigationBar)
        .alert("Clear the watch history?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) { app.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The progress of each video goes. The watchlist stays.")
        }
    }

    @ViewBuilder
    private var entries: some View {
        let state = app.addonState
        SettingsRow(
            title: "Sources",
            detail: "\(app.sources.count) sources, \(state.addons.count) addons work"
                + (state.failures.isEmpty ? "" : ", \(state.failures.count) do not answer")
        ) { app.open(.sources) }
        SettingsRow(
            title: "Switch profile",
            detail: "\(app.currentProfile?.name ?? ""). Each profile has its own history, watchlist, and settings."
        ) { app.open(.profiles) }
        SettingsRow(
            title: "Home rows",
            detail: "\(viewer.hiddenRows.count) rows off. Turn each row of the home screen off or on."
        ) { app.open(.homeRows) }
    }

    @ViewBuilder
    private var viewing: some View {
        SettingsSection(title: "Viewing")
        SettingsRow(title: "Subtitles", detail: "\(onOff(viewer.subtitlesOn)). The Subtitles button changes them while you watch.") {
            app.updateSettings { $0.subtitlesOn.toggle() }
        }
        SettingsChoiceRow(
            title: "Subtitle language",
            detail: SettingsStore.languageName(viewer.subtitleLanguage.isEmpty ? "en" : viewer.subtitleLanguage),
            options: SettingsStore.languages.dropFirst().map(\.code),
            current: viewer.subtitleLanguage,
            label: SettingsStore.languageName
        ) { code in app.updateSettings { $0.subtitleLanguage = code } }
        choice("Subtitle size", viewer.subtitleSize.label, \.subtitleSize, \.label)
        choice("Subtitle text color", viewer.subtitleColor.label, \.subtitleColor, \.label)
        choice("Subtitle background", "\(viewer.subtitleBackground.label). A box behind the text.", \.subtitleBackground, \.label)
        choice("Subtitle font", viewer.subtitleFont.label, \.subtitleFont, \.label)
        choice("Side bars", "\(viewer.sideBars.label). For a video of another shape, such as an old 4:3 anime.", \.sideBars, \.label)
        choice("Subtitle edge", "\(viewer.subtitleEdge.label). An edge keeps text readable with no background.", \.subtitleEdge, \.label)
        choice("Video filter", filterText(viewer.videoFilter), \.videoFilter, filterText)
        SettingsChoiceRow(
            title: "Audio language",
            detail: SettingsStore.languageName(viewer.audioLanguage),
            options: SettingsStore.languages.map(\.code),
            current: viewer.audioLanguage,
            label: SettingsStore.languageName
        ) { code in app.updateSettings { $0.audioLanguage = code } }
        SettingsStepperRow(
            title: "Audio delay",
            detail: "\(Timing.label(viewer.audioDelayMs)). The sound plays later than the picture. It fixes a sound system that adds a delay.",
            decrease: { shiftAudio(-1) },
            increase: { shiftAudio(1) }
        )
        SettingsRow(title: "Play the next episode", detail: "\(onOff(viewer.autoplayNext)). A countdown at the end of an episode starts the next one.") {
            app.updateSettings { $0.autoplayNext.toggle() }
        }
        SettingsRow(
            title: "Skip intros automatically",
            detail: "\(onOff(viewer.autoSkipIntro)). The app jumps over the opening and the recap of an anime episode when it knows their times."
        ) { app.updateSettings { $0.autoSkipIntro.toggle() } }
    }

    @ViewBuilder
    private var torrents: some View {
        SettingsSection(title: "Torrents")
        SettingsRow(
            title: "Show torrent streams",
            detail: "\(onOff(viewer.showTorrents)). Torrent streams connect you to other people, who can see your IP address."
        ) { app.updateSettings { $0.showTorrents.toggle() } }
        SettingsRow(title: "Direct links first", detail: "\(onOff(viewer.directFirst)). Direct links show above torrents in the list of streams.") {
            app.updateSettings { $0.directFirst.toggle() }
        }
        SettingsRow(title: "Share while streaming", detail: "\(onOff(viewer.torrentUpload)). When off, the app uploads almost nothing.") {
            app.updateSettings { $0.torrentUpload.toggle() }
        }
        SettingsRow(title: "VPN notice at start", detail: onOff(viewer.vpnNotice)) {
            app.updateSettings { $0.vpnNotice.toggle() }
        }
    }

    /// The exporter and the importer are on two rows. On iOS 16, only one file sheet works on one view.
    @ViewBuilder
    private var backup: some View {
        SettingsRow(
            title: "Back up",
            detail: "Saves the watchlist, the history, the favourite channels, the settings, and the source list in one file."
        ) {
            guard let text = app.exportBackup() else { return }
            backupFile = SettingsBackupFile(text: text)
            exporting = true
        }
        .fileExporter(isPresented: $exporting, document: backupFile, contentType: .json, defaultFilename: "zettastream-backup") { result in
            switch result {
            case .success: app.show("The backup is saved.")
            case .failure(let error): app.show("The backup was not saved: \(error.localizedDescription)")
            }
            backupFile = nil
        }
        SettingsRow(title: "Restore", detail: restoreReport ?? "Restores a backup. It replaces the data on this device.") {
            importing = true
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let report = try app.restoreBackup(SettingsFileReader.text(of: result.get()))
                restoreReport = report
                app.show(report)
            } catch {
                restoreReport = nil
                app.show(error.localizedDescription)
            }
        }
    }

    /// A row with each case of a choice of the viewer settings.
    private func choice<T: CaseIterable & Hashable>(
        _ title: String, _ detail: String, _ key: WritableKeyPath<ViewerSettings, T>, _ label: @escaping (T) -> String
    ) -> some View where T.AllCases == [T] {
        SettingsChoiceRow(title: title, detail: detail, options: T.allCases, current: viewer[keyPath: key], label: label) { value in
            app.updateSettings { $0[keyPath: key] = value }
        }
    }

    private func filterText(_ filter: VideoFilter) -> String {
        filter.label + (filter.colour ? " (more power)" : "")
    }

    private func shiftAudio(_ direction: Int) {
        let next = Timing.step(viewer.audioDelayMs, direction: direction, step: Timing.audioStep, limit: Timing.audioLimit)
        app.updateSettings { $0.audioDelayMs = next }
    }

    private func onOff(_ on: Bool) -> String { on ? "On" : "Off" }
}
