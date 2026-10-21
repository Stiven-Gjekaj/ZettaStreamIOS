import SwiftUI
import ZettaCore

/// "Who is watching?" first, then the tabs. The player covers the full screen.
struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Group {
            if app.profileChosen {
                tabs
            } else {
                ProfilesScreen(startup: true)
            }
        }
        .fullScreenCover(item: $app.playback) { playback in
            PlayerScreen(playback: playback)
                .environmentObject(app)
        }
        .overlay(alignment: .bottom) { ToastView() }
        .zettaScreen()
    }

    private var tabs: some View {
        TabView(selection: $app.tab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                NavigationStack(path: app.path(tab)) {
                    root(tab)
                        .navigationDestination(for: Route.self, destination: destination)
                }
                .tabItem { Label(tab.title, systemImage: tab.icon) }
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func root(_ tab: Tab) -> some View {
        switch tab {
        case .home: HomeScreen()
        case .search: SearchScreen()
        case .library: LibraryScreen()
        case .live: LiveScreen()
        case .settings: SettingsScreen()
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .detail(let preview): DetailScreen(preview: preview)
        case .streams(let request): StreamsScreen(request: request)
        case .autoPlay(let request): AutoPlayScreen(request: request)
        case .catalog(let row): CatalogScreen(row: row)
        case .sources: SourcesScreen()
        case .homeRows: HomeRowsScreen()
        case .profiles: ProfilesScreen(startup: false)
        case .editProfile(let id): EditProfileScreen(id: id)
        }
    }
}
