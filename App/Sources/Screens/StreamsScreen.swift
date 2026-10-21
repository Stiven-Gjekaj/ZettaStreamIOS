import SwiftUI
import ZettaCore

/// The streams of one video from all addons. Each addon shows its streams when it answers.
struct StreamsScreen: View {
    let request: VideoRequest
    @EnvironmentObject private var app: AppModel
    @StateObject private var model = StreamsModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                messages
                ForEach(Array(model.sections.enumerated()), id: \.offset) { _, section in
                    Text(section.title.uppercased())
                        .font(Karla.font(12, .semibold))
                        .kerning(1.5)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 22)
                        .padding(.bottom, 6)
                    ForEach(StreamRowID.of(section), id: \.id) { row in
                        let listed = row.listed
                        StreamRow(listed: listed, failed: app.container.health.failedRecently(listed)) {
                            play(listed)
                        }
                        .padding(.vertical, 5)
                    }
                }
                ForEach(model.notes, id: \.self) { note in
                    Text(note.text)
                        .font(Karla.font(12))
                        .foregroundStyle(note.error ? Palette.danger : Palette.textSecondary)
                        .padding(.top, 8)
                }
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .zettaScreen()
        .onAppear { model.start(app: app, request: request) }
        .onChange(of: app.settings.directFirst) { model.arrange(directFirst: $0) }
    }

    private var asked: Int { app.streamAddonCount(request) }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(request.meta.name)
                .font(Karla.font(26, .heavy, relativeTo: .title))
            if request.label != request.meta.name {
                Text(request.label)
                    .font(Karla.font(16))
                    .foregroundStyle(Palette.textSecondary)
            }
            Text(model.done
                 ? "\(Display.count(model.streamCount, "stream")) from \(model.playable.count) of \(Display.count(asked, "addon"))"
                 : "Asking \(Display.count(asked, "addon")) for streams")
                .font(Karla.font(14))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 8)
            if !model.done {
                TitleLoadingBar().padding(.vertical, 8)
            }
            TitleFlow(spacing: 10, lineSpacing: 10) {
                Button("Reload streams") { model.load(app: app, request: request, reload: true) }
                    .buttonStyle(.zSecondary)
                Button(app.settings.directFirst ? "Direct links first: on" : "Direct links first: off") {
                    app.toggleDirectFirst()
                }
                .buttonStyle(.zSecondary)
            }
            .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var messages: some View {
        if asked == 0 {
            TitleMessage(
                title: "No addon gives streams for this title",
                text: "Add an addon that gives streams in Settings, Sources. The addon must accept IDs like \(request.videoId.split(separator: ":").first.map(String.init) ?? request.videoId)."
            )
        } else if model.done && model.playable.isEmpty {
            let hidden = model.groups.reduce(0) { $0 + $1.hiddenTorrents }
            TitleMessage(
                title: "No playable stream",
                text: hidden > 0
                    ? "\(Display.count(hidden, "torrent stream")) are hidden. They show when Settings, Show torrent streams is on."
                    : "No addon found a stream for this video."
            )
        }
    }

    private func play(_ listed: ListedStream) {
        app.playStream(listed, of: request, subtitles: model.subtitles,
                       ranked: app.rankedStreams(model.groups, type: request.meta.type))
    }
}

/// The identity of a row: the addon and the link, or the torrent and its file.
/// A second copy of the same stream gets a number, so that each row has its own identity.
private struct StreamRowID {
    var id: String
    var listed: ListedStream

    static func of(_ section: StreamSection) -> [StreamRowID] {
        var seen: [String: Int] = [:]
        return section.streams.map { listed in
            let key = StreamHealth.key(listed)
            let copies = seen[key, default: 0]
            seen[key] = copies + 1
            return StreamRowID(id: copies == 0 ? key : "\(key)#\(copies)", listed: listed)
        }
    }
}

/// A line under the list about one addon: an error, the hidden torrents, or the links that the app cannot play.
private struct StreamNote: Hashable {
    var text: String
    var error: Bool
}

/// The groups of the addons, and the order of the list.
@MainActor
private final class StreamsModel: ObservableObject {
    @Published private(set) var groups: [StreamGroup] = []
    @Published private(set) var sections: [StreamSection] = []
    @Published private(set) var done = false
    @Published private(set) var subtitles: [Subtitle] = []
    private var directFirst = false
    private var started = false
    private var loading: Task<Void, Never>?

    var playable: [StreamGroup] { groups.filter { !$0.streams.isEmpty } }
    var streamCount: Int { groups.reduce(0) { $0 + $1.streams.count } }

    var notes: [StreamNote] {
        groups.flatMap { group -> [StreamNote] in
            let name = group.addon.name
            if group.error != nil { return [StreamNote(text: "\(name): no answer", error: true)] }
            var lines: [StreamNote] = []
            if group.hiddenTorrents > 0 {
                lines.append(StreamNote(text: "\(name): \(Display.count(group.hiddenTorrents, "torrent stream")) hidden", error: false))
            }
            if group.unplayable > 0 {
                lines.append(StreamNote(text: "\(name): \(Display.count(group.unplayable, "link")) that the app cannot play", error: false))
            }
            return lines
        }
    }

    /// Loads the list one time. Back from the player shows the same list.
    func start(app: AppModel, request: VideoRequest) {
        guard !started else { return }
        started = true
        directFirst = app.settings.directFirst
        load(app: app, request: request, reload: false)
        let repo = app.container.addons
        let type = request.meta.type
        let videoId = request.videoId
        let alias = Display.imdbAlias(request.meta, videoId: videoId, episodes: request.episodes)
        Task { [weak self] in
            let found = await repo.subtitles(type: type, videoId: videoId, alias: alias)
            self?.subtitles = found
        }
    }

    /// Asks each addon for streams. A kept list shows at once, but Reload asks the addons again,
    /// because a slow addon sometimes answers with fewer streams.
    func load(app: AppModel, request: VideoRequest, reload: Bool) {
        loading?.cancel()
        groups = []
        sections = []
        done = false
        let repo = app.container.addons
        let type = request.meta.type
        let videoId = request.videoId
        let withTorrents = app.settings.showTorrents
        loading = Task { [weak self] in
            if !reload, let kept = await repo.cachedStreams(type: type, videoId: videoId, withTorrents: withTorrents) {
                guard let self, !Task.isCancelled else { return }
                groups = kept
                arrange(directFirst: directFirst)
                done = true
                return
            }
            var all: [StreamGroup] = []
            for await group in await repo.streams(type: type, videoId: videoId, withTorrents: withTorrents) {
                guard let self, !Task.isCancelled else { return }
                all.append(group)
                groups = all
                arrange(directFirst: directFirst)
            }
            guard !Task.isCancelled else { return }
            await repo.keepStreams(type: type, videoId: videoId, withTorrents: withTorrents, groups: all)
            self?.done = true
        }
    }

    /// Puts the streams in order. An addon can give more than 1000 torrents, so this runs one time for each answer.
    func arrange(directFirst: Bool) {
        self.directFirst = directFirst
        sections = StreamOrder.sections(groups.map { ListedStream.list($0.addon, $0.streams) }, directFirst: directFirst)
    }
}

/// One stream: the labels, the name, the badges, the addon, and the full text of the addon.
private struct StreamRow: View {
    let listed: ListedStream
    let failed: Bool
    let action: () -> Void
    @State private var expanded = false

    private var stream: AddonStream { listed.stream }
    /// A long text shows four lines first. A button shows all of it.
    private var long: Bool {
        let details = stream.details
        return details.split(separator: "\n").count > 4 || details.count > 160
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    if stream.isTorrent { TitleBadge(text: "TORRENT", strong: true) }
                    if failed { TitleBadge(text: "DID NOT START", strong: true) }
                    Text((stream.name ?? listed.addon.name).replacingOccurrences(of: "\n", with: " "))
                        .font(Karla.font(15, .semibold))
                        .lineLimit(2)
                }
                let badges = listed.info.badges
                if !badges.isEmpty {
                    TitleFlow(spacing: 6, lineSpacing: 6) {
                        ForEach(Array(badges.enumerated()), id: \.offset) { TitleBadge(text: $0.element) }
                    }
                    .padding(.top, 6)
                }
                Text(listed.addon.name)
                    .font(Karla.font(11))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 6)
                if !stream.details.isEmpty {
                    Text(stream.details)
                        .font(Karla.font(13))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(expanded ? nil : 4)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .padding(.trailing, long ? 28 : 0)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if long {
                Button { expanded.toggle() } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Show less" : "Show all")
            }
        }
    }
}
