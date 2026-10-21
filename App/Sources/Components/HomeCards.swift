import SwiftUI
import ZettaCore

/// The sizes of the cards and the side space of the home screen and the catalogs.
enum HomeSizes {
    /// The width of a poster card. An iPad has more space, so its cards are larger.
    static func posterWidth(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 140 : 112
    }

    static func gutter(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 32 : 16
    }

    /// The space between two cards of a row.
    static let cardSpacing: CGFloat = 12
}

/// The shape of a card image. Addons say "poster", "landscape", or "square".
enum HomeCardShape {
    case poster, landscape, square

    init(_ posterShape: String?) {
        switch posterShape?.lowercased() {
        case "landscape": self = .landscape
        case "square": self = .square
        default: self = .poster
        }
    }

    var widthScale: CGFloat {
        switch self {
        case .poster: 1
        case .landscape: 1.8
        case .square: 1.15
        }
    }

    var heightRatio: CGFloat {
        switch self {
        case .poster: 1.5
        case .landscape: 9.0 / 16.0
        case .square: 1
        }
    }
}

/// A card with the art of a title, its name, and a caption under it.
/// The caption is, for example, the episode to continue. With no caption, the card shows the kind and the year.
struct HomePosterCard: View {
    let meta: MetaPreview
    let width: CGFloat
    var progress: Double?
    var caption: String?
    /// A mark such as "NEW" at the top left of the art.
    var badge: String?

    var body: some View {
        let shape = HomeCardShape(meta.posterShape)
        let cardWidth = width * shape.widthScale
        VStack(alignment: .leading, spacing: 0) {
            art(shape)
                .frame(width: cardWidth, height: cardWidth * shape.heightRatio)
                .clipShape(RoundedRectangle(cornerRadius: corner))
            Text(meta.name)
                .font(Karla.font(14, .medium))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .padding(.top, 10)
            if let facts {
                Text(facts)
                    .font(Karla.font(12))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .frame(width: cardWidth, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var facts: String? {
        if let caption, caption != meta.name { return caption }
        let facts = Display.cardFacts(type: meta.type, releaseInfo: meta.releaseInfo)
        return facts.isEmpty ? nil : facts
    }

    private func art(_ shape: HomeCardShape) -> some View {
        ZStack {
            Palette.surfaceHigh
            // The name shows until the art comes, and when a title has no art.
            Text(meta.name)
                .font(Karla.font(13))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(8)
            if let poster = Display.cardPoster(meta.poster), let url = URL(string: poster) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if case .success(let image) = phase {
                        // A square image is often a channel logo, so it shows in full.
                        if shape == .square {
                            image.resizable().aspectRatio(contentMode: .fit).padding(10)
                        } else {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if let badge {
                Text(badge)
                    .font(Karla.font(11, .bold))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: corner))
                    .padding(6)
            }
        }
        .overlay(alignment: .topTrailing) {
            // The rating sits on the art, as on Miruro 2.0.
            if let rating = Display.rating(meta.imdbRating) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 10))
                    Text(rating).font(Karla.font(11, .semibold))
                }
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Palette.background.opacity(0.75), in: RoundedRectangle(cornerRadius: corner))
                .padding(6)
            }
        }
        .overlay(alignment: .bottom) {
            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Palette.surfaceHigh
                        Palette.accent.frame(width: geo.size.width * min(max(progress, 0), 1))
                    }
                }
                .frame(height: 4)
            }
        }
    }
}

/// "Explore more" at the end of a row. It has the size of the cards before it.
struct HomeMoreCard: View {
    let width: CGFloat
    let shape: HomeCardShape

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.right")
                .font(.system(size: 30, weight: .medium))
            Text("Explore more")
                .font(Karla.font(15, .semibold))
        }
        .foregroundStyle(Palette.textPrimary)
        .frame(width: width * shape.widthScale, height: width * shape.widthScale * shape.heightRatio)
        .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
        .contentShape(Rectangle())
    }
}

/// The title of a row, with a grey line of detail under it.
struct HomeSectionTitle: View {
    let text: String
    var detail: String?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(Karla.font(18, .semibold, relativeTo: .headline))
                .foregroundStyle(Palette.textPrimary)
            if let detail {
                Text(detail)
                    .font(Karla.font(12))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HomeSizes.gutter(sizeClass))
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}

/// A row of title cards. A tap opens the page of the title. The last card can open the whole catalog.
struct HomePosterRow: View {
    let metas: [MetaPreview]
    var onMore: (() -> Void)?
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let width = HomeSizes.posterWidth(sizeClass)
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: HomeSizes.cardSpacing) {
                ForEach(metas, id: \.homeKey) { meta in
                    Button { app.open(.detail(meta)) } label: {
                        HomePosterCard(meta: meta, width: width)
                    }
                    .buttonStyle(HomeCardButtonStyle())
                    .homeCardMenu(meta)
                }
                if let onMore {
                    Button(action: onMore) {
                        HomeMoreCard(width: width, shape: HomeCardShape(metas.first?.posterShape))
                    }
                    .buttonStyle(HomeCardButtonStyle())
                }
            }
            .padding(.horizontal, HomeSizes.gutter(sizeClass))
            .padding(.vertical, 8)
        }
    }
}

/// Grey boxes in the place of a row that loads.
struct HomePlaceholderRow: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let width = HomeSizes.posterWidth(sizeClass)
        HStack(spacing: HomeSizes.cardSpacing) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: corner)
                    .fill(Palette.surfaceHigh.opacity(0.5))
                    .frame(width: width, height: width * 1.5)
            }
        }
        .padding(.horizontal, HomeSizes.gutter(sizeClass))
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// A title and a grey text that tell the viewer what to do.
struct HomeMessage: View {
    let title: String
    let text: String
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Karla.font(20, .semibold, relativeTo: .title3))
                .foregroundStyle(Palette.textPrimary)
            Text(text)
                .font(Karla.font(15))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HomeSizes.gutter(sizeClass))
    }
}

/// A chip of a filter. The chip that is on is white.
struct HomeChip: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                }
                Text(text).font(Karla.font(14, .medium))
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .foregroundStyle(selected ? Palette.onAccent : Palette.textSecondary)
            .background(selected ? Palette.accent : Palette.surface, in: RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(selected ? Palette.accent : Palette.outline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A card dims a little while the finger is on it.
struct HomeCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// The actions of a long press on a card: the details, the watchlist, and the watched mark.
private struct HomeCardMenu: ViewModifier {
    let meta: MetaPreview
    /// The video that the watched mark acts on. A film is its own video. A series has no mark here.
    let videoId: String?
    let details: Bool
    @EnvironmentObject private var app: AppModel

    func body(content: Content) -> some View {
        content.contextMenu {
            if details {
                Button { app.open(.detail(meta)) } label: { Label("Details", systemImage: "info.circle") }
            }
            let inList = app.homeIsInWatchlist(meta.id)
            Button { app.toggleWatchlist(meta) } label: {
                Label(inList ? "Remove from the watchlist" : "Add to the watchlist", systemImage: inList ? "checkmark" : "plus")
            }
            if let videoId {
                let watched = app.homeIsWatched(videoId)
                Button { app.toggleWatched(videoId) } label: {
                    Label(watched ? "Mark not watched" : "Mark watched", systemImage: watched ? "checkmark.circle.fill" : "circle")
                }
            }
        }
    }
}

extension View {
    /// Adds the long press menu of a card. `videoId` is the video for the watched mark.
    /// With no `videoId`, a film gets the mark for its own ID.
    func homeCardMenu(_ meta: MetaPreview, videoId: String? = nil, details: Bool = false) -> some View {
        let video = videoId ?? (Display.typeKey(meta.type) == "movie" ? meta.id : nil)
        return modifier(HomeCardMenu(meta: meta, videoId: video, details: details))
    }
}

extension MetaPreview {
    /// One key for each card of a row. Two addons can give the same ID with two types.
    var homeKey: String { type + id }
}
