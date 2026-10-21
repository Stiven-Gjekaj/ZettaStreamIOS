import SwiftUI
import ZettaCore

/// The titles to continue, and the watchlist of the profile.
struct LibraryScreen: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        let data = app.library
        let resume = Library.continueWatching(data)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LibraryPageTitle(text: "Library")
                if resume.isEmpty && data.watchlist.isEmpty {
                    LibraryMessage(
                        title: "Your library is empty",
                        text: "Add a title to the watchlist from its page. What you watch shows here too."
                    )
                }
                if !resume.isEmpty {
                    LibrarySectionTitle(text: "Continue watching")
                    row {
                        ForEach(resume, id: \.videoId) { progress in
                            Button { app.open(.detail(progress.meta)) } label: {
                                LibraryResumeCard(progress: progress)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !data.watchlist.isEmpty {
                    LibrarySectionTitle(text: "Watchlist")
                    row {
                        ForEach(data.watchlist, id: \.libraryKey) { meta in
                            Button { app.open(.detail(meta)) } label: {
                                PosterCard(meta: meta, width: 112)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .zettaScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12, content: content)
                .padding(.horizontal, libraryGutter)
                .padding(.vertical, 8)
        }
    }
}

private extension MetaPreview {
    var libraryKey: String { type + "|" + id }
}
