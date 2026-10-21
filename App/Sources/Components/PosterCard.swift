import SwiftUI
import ZettaCore

/// A poster with the name, the kind, the year, and the rating under it.
struct PosterCard: View {
    let meta: MetaPreview
    var width: CGFloat = 120
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: Display.cardPoster(meta.poster))
                .frame(width: width, height: width * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay(alignment: .topTrailing) {
                    if let rating = Display.rating(meta.imdbRating) {
                        Text(rating)
                            .font(Karla.font(11, .bold))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let progress, progress > 0 {
                        GeometryReader { geo in
                            Rectangle().fill(Palette.accent).frame(width: geo.size.width * min(progress, 1), height: 3)
                        }
                        .frame(height: 3)
                        .background(Color.white.opacity(0.2))
                    }
                }
            Text(meta.name)
                .font(Karla.font(13, .semibold))
                .lineLimit(1)
            let facts = Display.cardFacts(type: meta.type, releaseInfo: meta.releaseInfo)
            if !facts.isEmpty {
                Text(facts)
                    .font(Karla.font(11))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }
}
