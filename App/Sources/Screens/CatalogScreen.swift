import SwiftUI
import ZettaCore

/// All the titles of one catalog in a grid, as in Search. Near the end of the grid, the
/// next page loads, for as long as the addon gives new titles.
struct CatalogScreen: View {
    let row: CatalogRow
    @EnvironmentObject private var app: AppModel
    @StateObject private var model = CatalogViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The next page loads when this many titles are left below the title on the screen.
    private static let preload = 12

    var body: some View {
        let width = HomeSizes.posterWidth(sizeClass)
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: width + 8), spacing: 14, alignment: .top)],
                alignment: .leading,
                spacing: 18
            ) {
                Section {
                    ForEach(Array(model.titles.enumerated()), id: \.element.homeKey) { index, meta in
                        Button { app.open(.detail(meta)) } label: {
                            HomePosterCard(meta: meta, width: width)
                        }
                        .buttonStyle(HomeCardButtonStyle())
                        .homeCardMenu(meta)
                        .onAppear {
                            if index >= model.titles.count - Self.preload {
                                Task { await model.loadNext(row, app: app) }
                            }
                        }
                    }
                } header: {
                    header
                } footer: {
                    footer
                }
            }
            .padding(.horizontal, HomeSizes.gutter(sizeClass))
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: row) { await model.start(row, app: app) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(row.title)
                .font(Karla.font(26, .heavy, relativeTo: .title))
                .foregroundStyle(Palette.textPrimary)
            Text("\(Display.typeLabel(row.catalog.type)) from \(row.addon.name)")
                .font(Karla.font(14))
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var footer: some View {
        if model.loading {
            ProgressView()
                .tint(Palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        } else if model.titles.isEmpty && model.started {
            HomeMessage(
                title: model.failed ? "The addon did not answer" : "No titles",
                text: model.failed ? "Press Back and try again later." : "This catalog gives no titles.")
        }
    }
}

/// The titles of one catalog, page after page.
@MainActor
final class CatalogViewModel: ObservableObject {
    @Published private(set) var titles: [MetaPreview] = []
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    /// True after the screen has its first titles, or after it asked for them.
    @Published private(set) var started = false
    private var more = false
    private var key: String?

    /// The pages of titles that each catalog loaded, so that Back from a title shows the same grid.
    private static var loaded: [String: (titles: [MetaPreview], more: Bool)] = [:]

    func start(_ row: CatalogRow, app: AppModel) async {
        guard key != row.key else { return }
        key = row.key
        if let start = Self.loaded[row.key] {
            titles = start.titles
            more = start.more
        } else {
            titles = await app.container.addons.cachedCatalog(row) ?? []
            more = CatalogPaging.canPage(row)
        }
        started = !titles.isEmpty
        // The first page, when the row has not loaded it yet.
        if titles.isEmpty { await loadNext(row, app: app, first: true) }
    }

    /// Loads the next page, when the addon can give one.
    func loadNext(_ row: CatalogRow, app: AppModel, first: Bool = false) async {
        guard !loading, first || more, key == row.key else { return }
        loading = true
        let page: [MetaPreview]?
        do {
            page = try await app.container.addons.catalog(CatalogPaging.page(row, loaded: titles.count))
        } catch {
            page = nil
        }
        loading = false
        started = true
        if let page {
            let next = CatalogPaging.add(titles, page: page)
            titles = next.titles
            more = next.more && CatalogPaging.canPage(row)
        } else {
            failed = true
            more = false
        }
        Self.loaded[row.key] = (titles, more)
    }
}
