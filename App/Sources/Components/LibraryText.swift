import SwiftUI

/// The space at the left and the right of a screen on a phone.
let libraryGutter: CGFloat = 16

/// The large title at the top of the search, library, and live TV screens.
struct LibraryPageTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Karla.font(26, .heavy, relativeTo: .largeTitle))
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, libraryGutter)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A title and a grey text under it, for an empty list or a problem.
struct LibraryMessage: View {
    let title: String
    let text: String

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
        .padding(libraryGutter)
    }
}

/// The title of a section, with the space of the Android section title around it.
struct LibrarySectionTitle: View {
    let text: String

    var body: some View {
        SectionTitle(text: text)
            .padding(.horizontal, libraryGutter)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A thin bar that moves while the data loads. It has no end, because the time to load is not known.
struct LibraryLoadingBar: View {
    @State private var moving = false

    var body: some View {
        GeometryReader { geo in
            let part = geo.size.width * 0.3
            Rectangle()
                .fill(Palette.accent)
                .frame(width: part)
                .offset(x: moving ? geo.size.width : -part)
        }
        .frame(height: 3)
        .background(Palette.surfaceHigh)
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { moving = true }
        }
        .accessibilityLabel("Loading")
    }
}
