import SwiftUI

/// Puts the views in lines, and starts a new line when a view does not fit.
struct TitleFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let frames = place(subviews, width: width)
        let used = frames.map(\.maxX).max() ?? 0
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: proposal.width ?? used, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = place(subviews, width: bounds.width)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    private func place(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            size.width = min(size.width, width)
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return frames
    }
}

/// A fact of a title in a small frame, such as the year or a genre.
struct TitleFactChip: View {
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

/// A short label on a stream, such as "1080p". A strong badge has a light fill.
struct TitleBadge: View {
    let text: String
    var strong = false

    var body: some View {
        Text(text)
            .font(Karla.font(11, .bold))
            .foregroundStyle(strong ? Palette.onAccent : Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(strong ? Palette.textSecondary : Palette.outline, in: RoundedRectangle(cornerRadius: corner))
    }
}

/// A chip that the viewer can choose. The chosen chip is white.
struct TitleChip: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(Karla.font(14, selected ? .semibold : .regular))
                .foregroundStyle(selected ? Palette.onAccent : Palette.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Palette.accent : Palette.surface, in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner).stroke(selected ? Palette.accent : Palette.outline))
        }
        .buttonStyle(.plain)
    }
}

/// A heading of a part of the title page, with an optional grey line under it.
struct TitleHeading: View {
    let text: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(Karla.font(19, .bold, relativeTo: .headline))
            if let detail {
                Text(detail)
                    .font(Karla.font(13))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 32)
        .padding(.bottom, 12)
    }
}

/// A title and a grey text that tell why a list is empty.
struct TitleMessage: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Karla.font(20, .semibold))
            Text(text)
                .font(Karla.font(15))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
}

/// A thin bar that moves while the app waits for an answer of unknown length.
struct TitleLoadingBar: View {
    @State private var moving = false

    var body: some View {
        GeometryReader { geo in
            let part = geo.size.width * 0.3
            ZStack(alignment: .leading) {
                Palette.surfaceHigh
                Palette.accent
                    .frame(width: part)
                    .offset(x: moving ? geo.size.width : -part)
            }
            .clipped()
        }
        .frame(height: 4)
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { moving = true }
        }
        // A bar of 3 points is too small to touch with VoiceOver. The content of the
        // screen comes when the load ends, and VoiceOver reads it then.
        .accessibilityHidden(true)
    }
}
