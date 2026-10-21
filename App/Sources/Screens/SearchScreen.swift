import SwiftUI
import ZettaCore

/// The state of the search. It lives as long as the tab, so that Back from a title shows the same results.
@MainActor
final class SearchModel: ObservableObject {
    /// The text in the field.
    @Published var text = ""
    /// The text of the last search. The search starts when the viewer presses Search, not while the viewer types.
    @Published private(set) var query = ""
    @Published private(set) var results: [MetaPreview] = []
    @Published private(set) var searching = false
    private var task: Task<Void, Never>?

    /// Searches all catalogs that support a search. The results come as each addon answers.
    func search(_ text: String, app: AppModel) {
        let next = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // The same search shows the results that are on the screen.
        if next == query && !next.isEmpty && (searching || !results.isEmpty) { return }
        task?.cancel()
        query = next
        results = []
        guard !next.isEmpty else {
            searching = false
            return
        }
        searching = true
        let addons = app.container.addons
        task = Task { [weak self] in
            for await list in await addons.search(next) {
                guard !Task.isCancelled else { return }
                self?.results = list
            }
            guard !Task.isCancelled else { return }
            app.addSearchHistory(next)
            self?.searching = false
        }
    }

    /// Empties the field and stops the search. The recent searches show again.
    func clear() {
        task?.cancel()
        text = ""
        query = ""
        results = []
        searching = false
    }
}

struct SearchScreen: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var model = SearchModel()
    @StateObject private var voice = VoiceSearch()
    @FocusState private var fieldFocused: Bool
    /// True after the viewer scrolls the results. Then a better match that comes late does not move the list.
    @State private var scrolled = false

    private var history: [String] { app.settings.searchHistory }
    private var showRecent: Bool { model.query.isEmpty && !history.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryPageTitle(text: "Search")
                .padding(.top, 16)
                .padding(.bottom, 8)
            field
            if model.searching {
                LibraryLoadingBar()
                    .padding(.horizontal, libraryGutter)
                    .padding(.vertical, 8)
            }
            content
        }
        .zettaScreen()
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { voice.stop() }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.textSecondary)
            TextField("", text: $model.text, prompt: Text("Search titles").foregroundColor(Palette.textSecondary))
                .font(Karla.font(16))
                .foregroundStyle(Palette.textPrimary)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($fieldFocused)
                .onSubmit(submit)
            if !model.text.isEmpty {
                Button {
                    model.clear()
                    scrolled = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.textSecondary)
                }
                .accessibilityLabel("Clear the search")
            }
            Button(action: listen) {
                Image(systemName: voice.listening ? "mic.fill" : "mic")
                    .font(.system(size: 18))
                    .foregroundStyle(voice.listening ? Palette.accent : Palette.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(voice.listening ? "Stop listening" : "Voice search")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .overlay(RoundedRectangle(cornerRadius: corner).stroke(fieldFocused ? Palette.accent : Palette.outline, lineWidth: fieldFocused ? 2 : 1))
        .contentShape(Rectangle())
        .onTapGesture { fieldFocused = true }
        .padding(.horizontal, libraryGutter)
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id("top")
                    status
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14, alignment: .top)], spacing: 18) {
                        ForEach(model.results, id: \.searchKey) { meta in
                            Button { app.open(.detail(meta)) } label: {
                                PosterCard(meta: meta, width: 112)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("card:\(meta.id)")
                        }
                    }
                    .padding(.horizontal, libraryGutter)
                    .padding(.vertical, 16)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in scrolled = true })
            // Better matches can come after the first answers. The list goes back to the top for them,
            // but not after the viewer scrolls it.
            .onChange(of: model.results.first?.searchKey) { _ in
                if !scrolled { proxy.scrollTo("top", anchor: .top) }
            }
            .onChange(of: model.query) { _ in scrolled = false }
        }
    }

    @ViewBuilder
    private var status: some View {
        if !model.searching && !model.query.isEmpty && model.results.isEmpty {
            LibraryMessage(title: "Nothing found", text: "No catalog with search found \"\(model.query)\".")
        } else if showRecent {
            recent
        } else if model.query.isEmpty {
            LibraryMessage(title: "Find a film, a series, or an anime", text: "Type or say a title, and press Search.")
        } else if !model.results.isEmpty {
            Text("\(Display.count(model.results.count, "result")) for \"\(model.query)\"")
                .font(Karla.font(14))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, libraryGutter)
                .padding(.top, 12)
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent searches")
                .font(Karla.font(17, .semibold, relativeTo: .headline))
                .accessibilityAddTraits(.isHeader)
            SearchFlowLayout(spacing: 10) {
                ForEach(history, id: \.self) { past in
                    Button {
                        model.text = past
                        submit()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 15))
                            Text(past).lineLimit(1)
                        }
                    }
                    .buttonStyle(.zSecondary)
                }
                Button(action: app.clearSearchHistory) {
                    Text("Clear").foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.zSecondary)
                .accessibilityLabel("Clear the recent searches")
            }
        }
        .padding(.horizontal, libraryGutter)
        .padding(.vertical, 16)
    }

    /// Starts voice search, or stops it. The words go into the field, and the search starts when the viewer stops talking.
    private func listen() {
        if voice.listening {
            voice.stop()
            return
        }
        fieldFocused = false
        voice.start(
            onWords: { model.text = $0 },
            onEnd: { said in
                guard !said.isEmpty else { return }
                model.text = said
                submit()
            },
            onError: app.show)
    }

    private func submit() {
        fieldFocused = false
        model.search(model.text, app: app)
    }
}

private extension MetaPreview {
    var searchKey: String { type + "|" + id }
}
