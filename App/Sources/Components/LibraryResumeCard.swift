import SwiftUI
import ZettaCore

/// A poster of a title to continue. It shows the part that the viewer saw, and the episode under the name.
struct LibraryResumeCard: View {
    let progress: WatchProgress
    var width: CGFloat = 112

    private var part: Double? {
        progress.duration > 0 ? Double(progress.position) / Double(progress.duration) : nil
    }

    /// The episode to continue, or else the kind and the year.
    private var caption: String {
        let label = progress.label
        if !label.isEmpty && label != progress.meta.name { return label }
        return Display.cardFacts(type: progress.meta.type, releaseInfo: progress.meta.releaseInfo)
    }

    var body: some View {
        let meta = progress.meta
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: Display.cardPoster(meta.poster))
                .frame(width: width, height: width * 1.5)
                .overlay(alignment: .bottom) {
                    if let part {
                        GeometryReader { geo in
                            Rectangle().fill(Palette.accent).frame(width: geo.size.width * min(max(part, 0), 1), height: 4)
                        }
                        .frame(height: 4)
                        .background(Palette.surfaceHigh)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: corner))
            Text(meta.name)
                .font(Karla.font(13, .semibold))
                .lineLimit(1)
            if !caption.isEmpty {
                Text(caption)
                    .font(Karla.font(11))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
