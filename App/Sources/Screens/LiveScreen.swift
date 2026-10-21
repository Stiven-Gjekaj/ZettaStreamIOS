import SwiftUI
import ZettaCore

/// The channels of the playlists, with what is on now and next.
struct LiveScreen: View {
    @EnvironmentObject private var app: AppModel
    /// The chosen group. Nil is All.
    @State private var group: String?
    @State private var index = LiveIndex()

    var body: some View {
        let live = app.live
        let favorites = app.library.favoriteChannels
        index.update(live.channels)
        let shown = index.shown(group: group, favorites: favorites)
        return TimelineView(.everyMinute) { context in
            let now = Int64(context.date.timeIntervalSince1970 * 1000)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header(live)
                    if !app.sources.contains(where: { $0.kind == .playlist }) {
                        LibraryMessage(
                            title: "No playlists",
                            text: "Add an M3U playlist in Settings, Sources to watch live TV. Add an XMLTV guide to see what is on now."
                        )
                    }
                    if !live.failures.isEmpty {
                        failures(live.failures)
                    }
                    if index.groups.count > 1 || !favorites.isEmpty {
                        chips(favorites: favorites)
                    }
                    ForEach(Array(shown.enumerated()), id: \.element.url) { position, channel in
                        let key = index.key(channel)
                        LiveChannelRow(channel: channel, guide: live.guide, now: now, favorite: favorites.contains(key)) {
                            app.play(.live(channels: shown, index: position))
                        }
                        .contextMenu { favoriteButton(channel, key: key, favorite: favorites.contains(key)) }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .zettaScreen()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { app.loadLiveIfNeeded() }
    }

    @ViewBuilder
    private func header(_ live: LiveState) -> some View {
        LibraryPageTitle(text: "Live TV")
        Text(live.loading ? "Loading \(live.channels.count) channels and the guide" : "\(live.channels.count) channels")
            .font(Karla.font(14))
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, libraryGutter)
        if live.loading {
            LibraryLoadingBar()
                .padding(.horizontal, libraryGutter)
                .padding(.vertical, 8)
        }
    }

    /// Each playlist or guide that did not load, with its error.
    private func failures(_ failures: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(failures.keys.sorted(), id: \.self) { url in
                let playlist = app.sources.contains { $0.url == url && $0.kind == .playlist }
                VStack(alignment: .leading, spacing: 2) {
                    Text((playlist ? "Playlist does not load: " : "Guide does not load: ") + (failures[url] ?? ""))
                        .font(Karla.font(14, .medium))
                        .foregroundStyle(Palette.danger)
                    Text(url)
                        .font(Karla.font(12))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Button("Try again", action: app.reloadLive)
                .buttonStyle(.zSecondary)
                .disabled(app.live.loading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, libraryGutter)
        .padding(.vertical, 8)
    }

    /// All, then Favourites, then the largest groups of the playlists.
    private func chips(favorites: Set<String>) -> some View {
        let options: [String?] = [nil] + (favorites.isEmpty ? [] : [LiveIndex.favorites]) + index.groups
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    LiveChip(text: option == LiveIndex.favorites ? "Favourites" : option ?? "All", selected: option == group) {
                        group = option
                    }
                }
            }
            .padding(.horizontal, libraryGutter)
            .padding(.vertical, 10)
        }
    }

    private func favoriteButton(_ channel: Channel, key: String, favorite: Bool) -> some View {
        Button {
            app.toggleFavorite(channel, key: key)
        } label: {
            Label(favorite ? "Remove from the favourites" : "Add to the favourites", systemImage: favorite ? "star.slash" : "star")
        }
    }
}

/// The favourite keys and the groups of the channels. It finds them again only when the channels change.
private final class LiveIndex {
    /// The chip that shows only the favourite channels. It is not the name of a playlist group.
    static let favorites = "\u{0}favourites"

    private var channels: [Channel] = []
    private var keys: [String: String] = [:]
    /// The groups to show: at most 40, with the largest first.
    private(set) var groups: [String] = []

    func update(_ next: [Channel]) {
        guard next != channels else { return }
        channels = next
        keys = Channel.favoriteKeys(next)
        var counts: [String: (count: Int, first: Int)] = [:]
        for (position, name) in next.compactMap(\.group).enumerated() {
            counts[name, default: (0, position)].count += 1
        }
        groups = counts.sorted { a, b in
            a.value.count != b.value.count ? a.value.count > b.value.count : a.value.first < b.value.first
        }
        .prefix(40)
        .map(\.key)
    }

    func key(_ channel: Channel) -> String { keys[channel.url] ?? channel.key }

    /// The favourites come first in All, and alone in Favourites.
    func shown(group: String?, favorites: Set<String>) -> [Channel] {
        switch group {
        case Self.favorites?:
            return channels.filter { favorites.contains(key($0)) }
        case nil:
            let favorite = channels.filter { favorites.contains(key($0)) }
            return favorite.isEmpty ? channels : favorite + channels.filter { !favorites.contains(key($0)) }
        case let name?:
            return channels.filter { $0.group == name }
        }
    }
}

/// One channel: its logo, its name, and what is on now and next.
private struct LiveChannelRow: View {
    let channel: Channel
    let guide: Guide
    let now: Int64
    let favorite: Bool
    let action: () -> Void

    var body: some View {
        let (current, next) = guide.nowAndNext(channel.tvgId, now: now)
        Button(action: action) {
            HStack(spacing: 16) {
                LiveChannelLogo(channel: channel)
                    .frame(width: 96, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if favorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13))
                                .accessibilityLabel("Favourite")
                        }
                        Text(channel.name)
                            .font(Karla.font(15))
                            .lineLimit(1)
                    }
                    if let current {
                        Text("\(liveTime(current.start))  \(current.title)")
                            .font(Karla.font(14))
                            .foregroundStyle(Palette.textPrimary.opacity(0.85))
                            .lineLimit(1)
                        LiveProgressBar(part: Double(now - current.start) / Double(max(current.stop - current.start, 1)))
                            .padding(.top, 2)
                    }
                    if let next {
                        Text("\(liveTime(next.start))  \(next.title)")
                            .font(Karla.font(13))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    } else if current == nil, let group = channel.group {
                        Text(group)
                            .font(Karla.font(13))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
            .contentShape(RoundedRectangle(cornerRadius: corner))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, libraryGutter)
        .padding(.vertical, 4)
    }
}

/// The part of the programme that is over, on 60 percent of the width.
private struct LiveProgressBar: View {
    let part: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * 0.6
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.background)
                Rectangle().fill(Palette.accent).frame(width: width * min(max(part, 0), 1))
            }
            .frame(width: width)
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

/// The short time of a moment in milliseconds since 1970, in the form of the device.
private func liveTime(_ millis: Int64) -> String {
    Date(timeIntervalSince1970: TimeInterval(millis) / 1000).formatted(date: .omitted, time: .shortened)
}
