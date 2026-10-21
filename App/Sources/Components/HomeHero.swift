import SwiftUI
import ZettaCore

/// The large banner at the top of Home, after Miruro 2.0: the art of a title,
/// its logo or name, its facts, a short text, and three buttons.
/// The banner moves to the next title after a time. A swipe moves it too.
struct HomeHero: View {
    let items: [MetaPreview]
    /// The space above the banner that the status bar covers. The art goes under it.
    var topInset: CGFloat = 0
    /// Tells Home that the art of the first title loaded, or that it cannot load.
    var onCoverLoaded: () -> Void = {}
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var index = 0

    /// The time that each title of the banner shows.
    private static let slideTime: UInt64 = 8_000_000_000

    var body: some View {
        if !items.isEmpty {
            let meta = items[index % items.count]
            let height = (sizeClass == .regular ? 440 : 320) + topInset
            ZStack(alignment: .bottomLeading) {
                art(meta)
                    .id(meta.homeKey)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
                // The text stays easy to read on any art.
                LinearGradient(
                    stops: [
                        .init(color: Palette.background.opacity(0.92), location: 0),
                        .init(color: Palette.background.opacity(0.35), location: 0.55),
                        .init(color: Palette.background.opacity(0), location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing)
                LinearGradient(
                    stops: [
                        .init(color: Palette.background.opacity(0), location: 0.45),
                        .init(color: Palette.background, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
                content(meta)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, HomeSizes.gutter(sizeClass))
                    .padding(.trailing, sizeClass == .regular ? 300 : 32)
                    .padding(.bottom, 24)
                dots
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(swipe)
            .animation(.easeInOut(duration: 0.4), value: index)
            .onChange(of: items.map(\.homeKey)) { _ in index = 0 }
            .task(id: items.count) {
                guard items.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: Self.slideTime)
                    if Task.isCancelled { return }
                    index = (index + 1) % items.count
                }
            }
        }
    }

    private func art(_ meta: MetaPreview) -> some View {
        Group {
            if let address = meta.background ?? meta.poster, let url = URL(string: address) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .onAppear(perform: onCoverLoaded)
                    case .failure:
                        Palette.surface.onAppear(perform: onCoverLoaded)
                    default:
                        Palette.surface
                    }
                }
            } else {
                Palette.surface.onAppear(perform: onCoverLoaded)
            }
        }
    }

    private func content(_ meta: MetaPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let logo = meta.logo, let url = URL(string: logo) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        name(meta)
                    }
                }
                .frame(height: sizeClass == .regular ? 90 : 70, alignment: .leading)
                .frame(maxWidth: 260, alignment: .leading)
                .accessibilityLabel(meta.name)
            } else {
                name(meta)
            }
            let facts = [Display.year(meta.releaseInfo), Display.kind(meta.type)].compactMap { $0 } + meta.genres.prefix(3)
            if !facts.isEmpty {
                HomeFlowLayout(spacing: 8, maxLines: 2) {
                    ForEach(facts, id: \.self) { HomeFactChip(text: $0) }
                }
            }
            if let description = meta.description, !description.isEmpty {
                Text(description)
                    .font(Karla.font(14))
                    .foregroundStyle(Palette.textPrimary.opacity(0.85))
                    .lineLimit(3)
            }
            HStack(spacing: 10) {
                Button { app.homeWatchNow(meta) } label: {
                    Label("Watch now", systemImage: "play.fill")
                }
                .buttonStyle(.zPrimary)
                Button { app.open(.detail(meta)) } label: {
                    Label("Details", systemImage: "info.circle")
                }
                .buttonStyle(.zSecondary)
                Button { app.toggleWatchlist(meta) } label: {
                    Image(systemName: app.homeIsInWatchlist(meta.id) ? "checkmark" : "plus")
                        .frame(height: 18)
                }
                .buttonStyle(.zSecondary)
                .accessibilityLabel("Watchlist")
            }
        }
    }

    private func name(_ meta: MetaPreview) -> some View {
        Text(meta.name)
            .font(Karla.font(28, .heavy, relativeTo: .title))
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One mark for each title. The mark of the title on screen is long and white.
    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                let current = i == index % items.count
                RoundedRectangle(cornerRadius: corner)
                    .fill(current ? Palette.textPrimary : Palette.outline)
                    .frame(width: current ? 26 : 10, height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard items.count > 1, abs(value.translation.width) > abs(value.translation.height) else { return }
                let step = value.translation.width < 0 ? 1 : items.count - 1
                index = (index + step) % items.count
            }
    }
}

/// A small fact, such as the year or a genre, in a thin frame. A dark fill keeps it easy to read on bright art.
struct HomeFactChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Karla.font(13))
            .foregroundStyle(Palette.textPrimary.opacity(0.85))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Palette.background.opacity(0.6), in: RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
    }
}

/// Puts the views in lines from the left, and starts a new line when a view does not fit.
/// The views after `maxLines` lines do not show.
struct HomeFlowLayout: Layout {
    var spacing: CGFloat = 8
    var maxLines = Int.max

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = place(subviews, width: proposal.width ?? .infinity)
        let width = frames.compactMap { $0?.maxX }.max() ?? 0
        let height = frames.compactMap { $0?.maxY }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = place(subviews, width: bounds.width)
        for (subview, frame) in zip(subviews, frames) {
            if let frame {
                subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
            } else {
                // A view that does not fit goes out of sight with no size.
                subview.place(at: CGPoint(x: bounds.minX, y: bounds.minY), proposal: .zero)
            }
        }
    }

    /// The frame of each view, or nil for a view after the last line.
    private func place(_ subviews: Subviews, width: CGFloat) -> [CGRect?] {
        var frames: [CGRect?] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var line = 1
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                line += 1
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            if line > maxLines {
                frames.append(nil)
                continue
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: min(size.width, width), height: size.height)))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return frames
    }
}
