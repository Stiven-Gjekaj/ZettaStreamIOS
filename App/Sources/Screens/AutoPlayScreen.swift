import SwiftUI
import ZettaCore

/// Asks each addon for streams and plays the best one at once. The player takes the
/// place of this screen, so Back goes to the episodes. A button shows the list of streams instead.
struct AutoPlayScreen: View {
    let request: VideoRequest
    @EnvironmentObject private var app: AppModel
    @StateObject private var model = AutoPlayModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            Text(request.meta.name)
                .font(Karla.font(26, .heavy, relativeTo: .title))
            if request.label != request.meta.name {
                Text(request.label)
                    .font(Karla.font(16))
                    .foregroundStyle(Palette.textSecondary)
            }
            if let failure = model.failure {
                Text(failure)
                    .font(Karla.font(16))
                    .padding(.top, 12)
            } else {
                Text(model.playing.map { "Playing: \($0)" }
                     ?? "Finding the best stream: \(Display.count(model.answered, "addon")) of \(asked) answered")
                    .font(Karla.font(14))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 12)
                TitleLoadingBar().padding(.vertical, 8)
            }
            Button("Choose from the list", action: showList)
                .buttonStyle(model.failure == nil ? .zSecondary : .zPrimary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .navigationBarTitleDisplayMode(.inline)
        .zettaScreen()
        .task(id: request) {
            let tab = app.tab
            guard let found = await model.find(app: app, request: request) else { return }
            app.playStream(found.best, of: request, subtitles: found.subtitles, ranked: found.ranked)
            app.closeTop(of: tab)
        }
    }

    private var asked: Int { app.streamAddonCount(request) }

    private func showList() {
        app.closeTop(of: app.tab, opening: .streams(request))
    }
}

/// Waits for the addons, and chooses the stream to play.
@MainActor
private final class AutoPlayModel: ObservableObject {
    /// With an ideal stream, the app waits this long for a better answer from the other addons.
    private static let idealWait: TimeInterval = 2.5
    /// The longest wait for slow addons when some stream is already there.
    private static let maxWait: TimeInterval = 8
    /// The longest wait for the subtitles after the stream is chosen.
    private static let subtitleWait: UInt64 = 4_500_000_000
    private static let step: UInt64 = 250_000_000

    @Published private(set) var answered = 0
    /// Why no stream plays, or nil while the app looks.
    @Published private(set) var failure: String?
    /// The short name of the stream that plays.
    @Published private(set) var playing: String?
    private var groups: [StreamGroup] = []
    private var finished = false

    /// The best stream, the ranked list for the fallbacks, and the subtitles. Nil when nothing plays.
    func find(app: AppModel, request: VideoRequest) async -> (best: ListedStream, ranked: [ListedStream], subtitles: [Subtitle])? {
        let repo = app.container.addons
        let settings = app.settings
        let type = request.meta.type
        let videoId = request.videoId
        let maxBytes = StreamOrder.streamableBytes(type: type)
        let health = app.container.health
        let alias = Display.imdbAlias(request.meta, videoId: videoId, episodes: request.episodes)
        let asked = app.streamAddonCount(request)
        let subtitles = Task { await repo.subtitles(type: type, videoId: videoId, alias: alias) }
        groups = []
        answered = 0
        failure = nil
        playing = nil
        finished = false

        var collector: Task<Void, Never>?
        if let kept = await repo.cachedStreams(type: type, videoId: videoId, withTorrents: settings.showTorrents) {
            groups = kept
            answered = kept.count
            finished = true
        } else {
            collector = Task { [weak self] in
                var all: [StreamGroup] = []
                for await group in await repo.streams(type: type, videoId: videoId, withTorrents: settings.showTorrents) {
                    all.append(group)
                    self?.groups = all
                    self?.answered = all.count
                }
                guard !Task.isCancelled else { return }
                await repo.keepStreams(type: type, videoId: videoId, withTorrents: settings.showTorrents, groups: all)
                self?.finished = true
            }
        }
        defer { collector?.cancel() }

        // Start with an ideal stream soon, with any stream after `maxWait`, or when all addons answered.
        let start = Date()
        while !finished {
            if Task.isCancelled { subtitles.cancel(); return nil }
            let waited = Date().timeIntervalSince(start)
            if let best = StreamOrder.best(listed, preferDirect: settings.directFirst, maxTorrentBytes: maxBytes, health: health) {
                if StreamOrder.isIdeal(best, preferDirect: settings.directFirst, maxTorrentBytes: maxBytes) && waited >= Self.idealWait { break }
                if waited >= Self.maxWait { break }
            }
            try? await Task.sleep(nanoseconds: Self.step)
        }
        let ranked = StreamOrder.ranked(listed, preferDirect: settings.directFirst, maxTorrentBytes: maxBytes, health: health)
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        Diagnostics.shared.log("AutoPlay", "\(videoId): \(ranked.count) streams after \(elapsed) ms, best \(ranked.first.map(StreamOrder.shortLabel) ?? "none")")
        guard let best = ranked.first, !Task.isCancelled else {
            subtitles.cancel()
            if !Task.isCancelled { failure = Self.reason(asked: asked, groups: groups) }
            return nil
        }
        playing = StreamOrder.shortLabel(best)
        let found = await Self.first(subtitles, within: Self.subtitleWait)
        guard !Task.isCancelled else { return nil }
        return (best: best, ranked: ranked, subtitles: found)
    }

    private var listed: [ListedStream] {
        groups.flatMap { ListedStream.list($0.addon, $0.streams) }
    }

    /// The subtitles, or none when they do not come in time.
    private static func first(_ task: Task<[Subtitle], Never>, within limit: UInt64) async -> [Subtitle] {
        await withTaskGroup(of: [Subtitle]?.self) { group in
            group.addTask { await task.value }
            group.addTask {
                try? await Task.sleep(nanoseconds: limit)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? []
        }
    }

    /// Tells why no stream plays.
    private static func reason(asked: Int, groups: [StreamGroup]) -> String {
        if asked == 0 { return "No addon gives streams for this title. Add one in Settings, Sources." }
        let hidden = groups.reduce(0) { $0 + $1.hiddenTorrents }
        if hidden > 0 {
            return "No addon found a playable stream. \(Display.count(hidden, "torrent stream")) are hidden. They show when Settings, Show torrent streams is on."
        }
        if !groups.isEmpty && groups.allSatisfy({ $0.error != nil }) {
            return "No addon answered. Open the list and press Reload streams, or go back."
        }
        return "No addon found a playable stream. Choose from the list, or go back."
    }
}
