import SwiftUI
import ZettaCore

/// The page of one title: the art, the facts, the buttons, the episodes, the About table, and more like this.
struct DetailScreen: View {
    let preview: MetaPreview
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var meta: Meta?
    @State private var season: Int??
    @State private var similar: [MetaPreview] = []

    /// The most titles in the More like this row.
    private static let similarMax = 15
    private let gutter: CGFloat = 16

    private var wide: Bool { sizeClass == .regular }
    private var base: MetaPreview { meta?.preview ?? preview }
    private var videos: [Video] { meta?.videos ?? [] }
    /// Some addons give one placeholder episode when they do not know the episodes. Then the page shows no episode list.
    private var placeholder: Bool { meta.map(Display.isPlaceholder) ?? false }
    private var isSeries: Bool { meta != nil && !videos.isEmpty && base.type != "movie" && !placeholder }
    private var seasons: [Int?] { Episodes.seasons(videos) }
    private var target: Video? { isSeries ? meta.flatMap { Episodes.nextToPlay($0, app.library) } : nil }
    private var selectedSeason: Int? {
        if let season { return season }
        if let target { return target.season }
        return seasons.first ?? nil
    }
    private var episodes: [Video] { Episodes.of(videos, season: selectedSeason) }
    private var similarRow: CatalogRow? {
        guard let meta else { return nil }
        return Similar.row(app.addonState.addons, type: meta.type, genres: meta.preview.genres)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                top
                if isSeries { episodeList }
                if let meta { about(meta) }
                if !similar.isEmpty { moreLikeThis }
            }
            .padding(.vertical, gutter)
        }
        .background(alignment: .top) { art }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .zettaScreen()
        // A new list of addons can give the full details, so the page asks again when the addons load.
        .task(id: "\(preview.type)|\(preview.id)|\(app.addonState.loading)") {
            let found = await app.container.addons.meta(preview)
            if !Task.isCancelled { meta = found }
        }
        .task(id: similarRow?.key) {
            guard let row = similarRow, let meta else { return }
            let metas = (try? await app.container.addons.catalog(row)) ?? []
            guard !Task.isCancelled else { return }
            similar = Array(metas.filter { $0.id != meta.id }.prefix(Self.similarMax))
        }
    }

    // MARK: The art

    /// The art fills the top of the page. It fades into the black at the left and below.
    private var art: some View {
        ZStack {
            RemoteImage(url: base.background ?? preview.background ?? base.poster ?? preview.poster)
                .opacity(0.7)
            LinearGradient(stops: [
                .init(color: Palette.background.opacity(0.95), location: 0),
                .init(color: Palette.background.opacity(0.4), location: 0.6),
                .init(color: Palette.background.opacity(0.1), location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            LinearGradient(stops: [
                .init(color: Palette.background.opacity(0), location: 0.4),
                .init(color: Palette.background, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
        .frame(height: wide ? 420 : 300)
        .frame(maxWidth: .infinity)
        .clipped()
        .ignoresSafeArea(edges: [.top, .horizontal])
        .allowsHitTesting(false)
    }

    // MARK: The top of the page

    private var top: some View {
        HStack(alignment: .top, spacing: wide ? 24 : 16) {
            if let poster = base.poster ?? preview.poster {
                RemoteImage(url: poster)
                    .frame(width: wide ? 180 : 110, height: wide ? 270 : 165)
                    .clipShape(RoundedRectangle(cornerRadius: corner))
            }
            VStack(alignment: .leading, spacing: 12) {
                name
                let facts = factList
                if !facts.isEmpty {
                    TitleFlow { ForEach(Array(facts.enumerated()), id: \.offset) { TitleFactChip(text: $0.element) } }
                }
                if let text = base.description ?? preview.description, !text.isEmpty {
                    Text(text)
                        .font(Karla.font(14))
                        .foregroundStyle(Palette.textPrimary.opacity(0.85))
                        .lineLimit(wide ? 6 : 8)
                }
                if let meta {
                    buttons(meta)
                } else {
                    ProgressView().tint(Palette.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, gutter)
        .padding(.top, 8)
    }

    /// The logo on a wide screen, or else the name.
    @ViewBuilder
    private var name: some View {
        if wide, let logo = base.logo ?? preview.logo, let url = URL(string: logo) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    nameText
                }
            }
            .frame(maxWidth: 360, maxHeight: 100, alignment: .leading)
            .accessibilityLabel(base.name)
        } else {
            nameText
        }
    }

    private var nameText: some View {
        Text(base.name)
            .font(Karla.font(wide ? 32 : 24, .heavy, relativeTo: .title))
            .lineLimit(2)
    }

    private var factList: [String] {
        [
            Display.year(base.releaseInfo ?? preview.releaseInfo),
            Display.kind(base.type),
            meta?.runtime,
            Display.rating(base.imdbRating ?? preview.imdbRating).map { "IMDb \($0)" },
        ].compactMap { $0 } + Array((base.genres.isEmpty ? preview.genres : base.genres).prefix(3))
    }

    private func buttons(_ meta: Meta) -> some View {
        TitleFlow(spacing: 10, lineSpacing: 10) {
            Button { play(isSeries ? target : nil) } label: {
                Label(playText, systemImage: "play.fill")
            }
            .buttonStyle(.zPrimary)
            .contextMenu {
                Button { play(isSeries ? target : nil, choose: true) } label: {
                    Label("Choose from the list", systemImage: "list.bullet")
                }
            }
            if let whole = wholeShow(meta) {
                Button("All seasons") {
                    app.open(.detail(whole))
                }
                .buttonStyle(.zSecondary)
            }
            if let trailer = Display.trailer(meta) {
                Button { app.openTrailer(trailer) } label: {
                    Label("Trailer", systemImage: "film")
                }
                .buttonStyle(.zSecondary)
            }
            let inList = app.library.watchlist.contains { $0.id == meta.id }
            Button { app.toggleWatchlist(meta.preview) } label: {
                Label(inList ? "In watchlist" : "Watchlist", systemImage: inList ? "checkmark" : "plus")
            }
            .buttonStyle(.zSecondary)
            if !isSeries {
                let watched = app.library.watched.contains(meta.id)
                Button { app.toggleWatched(meta.id) } label: {
                    Label(watched ? "Watched" : "Mark watched", systemImage: watched ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.zSecondary)
            }
        }
    }

    private var playText: String {
        guard isSeries else {
            return Episodes.resumes(app.library.progress[base.id]) ? "Resume" : "Watch now"
        }
        guard let target else { return "Watch now" }
        let resume = Episodes.resumes(app.library.progress[target.id])
        return (resume ? "Resume " : "Watch ") + (Episodes.number(target) ?? target.label)
    }

    /// Anime Kitsu gives each season as its own title. The IMDb ID opens the whole show under one name, with every season.
    private func wholeShow(_ meta: Meta) -> MetaPreview? {
        guard let imdb = meta.preview.imdbId, meta.id.hasPrefix("kitsu:"), meta.type != "movie",
              app.addonState.addons.contains(where: { $0.supports("meta", type: "series", id: imdb) }) else { return nil }
        var whole = MetaPreview(id: imdb, type: "series", name: Display.withoutSeasonSuffix(meta.name))
        whole.poster = meta.preview.poster
        return whole
    }

    /// Play starts the best stream at once. "Choose from the list" shows the list of streams.
    private func play(_ video: Video?, choose: Bool = false) {
        let id: String
        let label: String
        if let video {
            id = video.id
            label = Episodes.label(video)
        } else if placeholder, let only = videos.first {
            // The placeholder episode is the ID that the addons know for this title.
            id = only.id
            label = base.name
        } else {
            id = base.id
            label = base.name
        }
        let request = VideoRequest(meta: base, videoId: id, label: label,
                                   episodes: video == nil ? [] : Episodes.sorted(videos))
        app.open(choose ? .streams(request) : .autoPlay(request))
    }

    // MARK: The episodes

    @ViewBuilder
    private var episodeList: some View {
        let detail = Display.count(episodes.count, "episode") + (selectedSeason.map { $0 == 0 ? " · Specials" : " · Season \($0)" } ?? "")
        TitleHeading(text: "Episodes", detail: detail)
            .padding(.horizontal, gutter)
        if seasons.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(seasons.enumerated()), id: \.offset) { _, value in
                        TitleChip(text: Episodes.seasonName(value), selected: value == selectedSeason) {
                            season = .some(value)
                        }
                    }
                }
                .padding(.horizontal, gutter)
            }
            .padding(.bottom, 8)
        }
        let columns = Array(repeating: GridItem(.flexible(), spacing: wide ? 20 : 12, alignment: .top), count: wide ? 4 : 2)
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(episodes, id: \.id) { video in
                TitleEpisodeCard(video: video, library: app.library) { play(video) }
                    .contextMenu {
                        let watched = app.library.watched.contains(video.id)
                        Button { app.toggleWatched(video.id) } label: {
                            Label(watched ? "Mark not watched" : "Mark watched",
                                  systemImage: watched ? "circle" : "checkmark.circle")
                        }
                        Button { play(video, choose: true) } label: {
                            Label("Choose from the list", systemImage: "list.bullet")
                        }
                    }
            }
        }
        .padding(.horizontal, gutter)
        .padding(.vertical, 8)
    }

    // MARK: About

    @ViewBuilder
    private func about(_ meta: Meta) -> some View {
        let facts = Display.aboutFacts(meta)
        if !facts.isEmpty {
            TitleHeading(text: "About")
                .padding(.horizontal, gutter)
            VStack(spacing: 0) {
                ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(fact.label)
                            .foregroundStyle(Palette.textSecondary)
                            .frame(width: wide ? 160 : 110, alignment: .leading)
                        Text(fact.value)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(Karla.font(14))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(index % 2 == 0 ? Palette.surface : Palette.background)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
            .frame(maxWidth: wide ? 640 : .infinity, alignment: .leading)
            .padding(.horizontal, gutter)
        }
    }

    // MARK: More like this

    @ViewBuilder
    private var moreLikeThis: some View {
        TitleHeading(text: "More like this")
            .padding(.horizontal, gutter)
        let width: CGFloat = wide ? 150 : 112
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(similar, id: \.self) { item in
                    Button { app.open(.detail(item)) } label: {
                        PosterCard(meta: item, width: width)
                    }
                    .buttonStyle(.plain)
                }
                if let row = similarRow {
                    TitleMoreCard(width: width) { app.open(.catalog(row)) }
                }
            }
            .padding(.horizontal, gutter)
            .padding(.vertical, 8)
        }
    }
}

/// One episode: the picture with the number, the watched mark and the progress, then the name and the date.
private struct TitleEpisodeCard: View {
    let video: Video
    let library: LibraryData
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { RemoteImage(url: video.thumbnail) }
                    .overlay(alignment: .topLeading) {
                        if let episode = video.episode {
                            Text("EP \(episode)")
                                .font(Karla.font(12, .bold))
                                .foregroundStyle(Palette.onAccent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Palette.accent, in: RoundedRectangle(cornerRadius: corner))
                                .padding(8)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if library.watched.contains(video.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Palette.accent)
                                .background(Circle().fill(Palette.background))
                                .padding(8)
                                .accessibilityLabel("Watched")
                        }
                    }
                    .overlay(alignment: .bottomLeading) { progressBar }
                    .clipShape(RoundedRectangle(cornerRadius: corner))
                Text(video.label)
                    .font(Karla.font(14, .medium))
                    .lineLimit(1)
                    .padding(.top, 10)
                let line = [Episodes.number(video), video.released.map { String($0.prefix(10)) }]
                    .compactMap { $0 }.joined(separator: " · ")
                if !line.isEmpty {
                    Text(line)
                        .font(Karla.font(12))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress = library.progress[video.id], progress.duration > 0, !progress.isFinished {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Palette.background.opacity(0.6)
                    Palette.accent.frame(width: geo.size.width * min(1, Double(progress.position) / Double(progress.duration)))
                }
            }
            .frame(height: 4)
        }
    }
}

/// "Explore more" at the end of the row. It has the size of the cards before it.
private struct TitleMoreCard: View {
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 30, weight: .semibold))
                Text("Explore more")
                    .font(Karla.font(15, .semibold))
            }
            .frame(width: width, height: width * 1.5)
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
