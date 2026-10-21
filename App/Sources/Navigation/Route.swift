import Foundation
import ZettaCore

/// A screen that opens on top of a tab.
enum Route: Hashable {
    case detail(MetaPreview)
    case streams(VideoRequest)
    /// Finds the best stream of a video, then plays it. Play on a title opens this screen.
    case autoPlay(VideoRequest)
    /// All the titles of one catalog, page after page.
    case catalog(CatalogRow)
    case sources
    case homeRows
    case profiles
    /// Adds a profile when the ID is nil, or changes the profile with that ID.
    case editProfile(String?)
}

/// The tabs of the tab bar, in the order of the icon bar of the Android app.
enum Tab: String, CaseIterable, Hashable {
    case home, search, library, live, settings

    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .library: "Library"
        case .live: "Live TV"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .library: "bookmark"
        case .live: "tv"
        case .settings: "gearshape"
        }
    }
}
