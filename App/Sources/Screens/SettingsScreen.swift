import SwiftUI
import ZettaCore

/// The settings of the current profile, and the entries to the sources, the profiles, and the home rows.
struct SettingsScreen: View {
    @EnvironmentObject private var app: AppModel
    @State private var confirmClear = false

    private var viewer: ViewerSettings { app.settings }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                SettingsPageTitle(text: "Settings")
                entries
                viewing
                torrents
                SettingsSection(title: "App")
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
