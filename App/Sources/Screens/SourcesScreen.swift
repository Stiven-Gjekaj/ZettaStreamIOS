import SwiftUI
import UIKit
import ZettaCore

/// The source list as text, one URL on each line. Save replaces the full list.
struct SourcesScreen: View {
    @EnvironmentObject private var app: AppModel
    @State private var draft = ""
    @State private var loaded = false
    @State private var saved: String?
    @FocusState private var editing: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                SettingsPageTitle(text: "Sources")
                editor
                Text("Current list (\(app.sources.count))")
                    .font(Karla.font(18, .semibold, relativeTo: .headline))
                    .padding(.horizontal, settingsGutter)
                    .padding(.vertical, 8)
                ForEach(app.sources, id: \.url) { source in
                    SourceStatusRow(source: source, status: status(source))
                }
            }
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .zettaScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editing = false }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            draft = SourceList.format(app.sources)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paste one URL on each line: a Stremio addon manifest.json, an M3U playlist, or an XMLTV guide.")
                .font(Karla.font(14, relativeTo: .subheadline))
                .foregroundStyle(Palette.textSecondary)
            SourceKindsTable()
            TextEditor(text: $draft)
                .focused($editing)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
                .scrollContentBackground(.hidden)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(8)
                // A long list scrolls inside the editor, so Save and Paste stay near it.
                .frame(height: 220)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner).stroke(editing ? Palette.accent : Palette.outline))
            Text("The new list replaces the old list. To remove a source, remove its line. "
                + "The order of the lines sets the order of the rows on the home screen.")
                .font(Karla.font(13, relativeTo: .footnote))
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 10) {
                Button("Save", action: save).buttonStyle(.zPrimary)
                // The system paste button reads the clipboard with no prompt. A plain
                // button that reads UIPasteboard gets no text until the user permits it.
                PasteButton(payloadType: String.self) { texts in
                    Task { @MainActor in paste(texts.joined(separator: "\n")) }
                }
                .labelStyle(.titleOnly)
                .tint(Palette.surfaceHigh)
                .foregroundStyle(Palette.textPrimary)
            }
            if let saved {
                Text(saved)
                    .font(Karla.font(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(settingsGutter)
    }

    private func save() {
        editing = false
        let wanted = SourceList.parse(draft)
        let list = app.saveSources(draft)
        // When the write fails, the model shows the error and gives the old list. The draft then stays.
        guard list == wanted else {
            saved = nil
            return
        }
        draft = SourceList.format(list)
        saved = Self.report(list)
    }

    /// The text on the clipboard takes the place of the draft. Save then replaces the list.
    private func paste(_ text: String) {
        guard !text.isEmpty else {
            app.show("The clipboard has no text.")
            return
        }
        draft = text
    }

    /// Tells how many sources of each kind the list has, such as "Saved 3 sources: 2 addons, 1 playlist, and 0 guides."
    static func report(_ list: [Source]) -> String {
        func count(_ kind: SourceKind, _ word: String) -> String {
            let n = list.filter { $0.kind == kind }.count
            return "\(n) \(word)" + (n == 1 ? "" : "s")
        }
        return "Saved \(list.count) source" + (list.count == 1 ? "" : "s")
            + ": \(count(.addon, "addon")), \(count(.playlist, "playlist")), and \(count(.guide, "guide"))."
    }

    /// The state of one source, and false when it does not work.
    private func status(_ source: Source) -> (text: String, ok: Bool) {
        switch source.kind {
        case .addon:
            let url = Addon.normalizeManifestUrl(source.url)
            if let addon = app.addonState.addons.first(where: { $0.manifestUrl == url }) {
                return ("Addon: \(addon.name)" + (addon.manifest.configurationRequired ? " (needs configuration)" : ""), true)
            }
            if let failure = app.addonState.failures[source.url] {
                return ("Addon does not answer: \(failure)", false)
            }
            return ("Addon: loading", true)
        case .playlist:
            if let failure = app.live.failures[source.url] { return ("Playlist does not load: \(failure)", false) }
            return ("Playlist", true)
        case .guide:
            if let failure = app.live.failures[source.url] { return ("Guide does not load: \(failure)", false) }
            return ("TV guide", true)
        }
    }
}

/// The three kinds of line that the list reads.
private struct SourceKindsTable: View {
    private let kinds = [
        ("A Stremio addon", "https://.../manifest.json", "Catalogs, titles, streams, subtitles"),
        ("An IPTV playlist", "https://.../playlist.m3u", "Live channels"),
        ("A TV guide", "https://.../guide.xml.gz", "What is on now and next"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(kinds, id: \.0) { kind in
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.0).font(Karla.font(14, .semibold))
                    Text(kind.1)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Palette.textPrimary)
                    Text(kind.2)
                        .font(Karla.font(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: corner))
    }
}

/// One source of the current list, with its state.
private struct SourceStatusRow: View {
    let source: Source
    let status: (text: String, ok: Bool)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(status.text)
                .font(Karla.font(15))
                .foregroundStyle(status.ok ? Palette.textPrimary : Palette.danger)
            Text(Self.hidePath(source.url))
                .font(Karla.font(12, relativeTo: .caption))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: corner))
        .padding(.horizontal, settingsGutter)
        .padding(.vertical, 4)
    }

    /// Shows only the scheme and the host. A configured addon URL can hold a key in its path.
    static func hidePath(_ url: String) -> String {
        guard let range = url.range(of: "://") else { return url }
        let host = url[range.upperBound...].split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        return url[..<range.lowerBound] + "://" + host + "/..."
    }
}
