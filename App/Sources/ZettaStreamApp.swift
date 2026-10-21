import SwiftUI
import ZettaCore

@main
struct ZettaStreamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppModel()

    init() {
        #if DEBUG
        Diagnostics.shared.toConsole = true
        #endif
        // AsyncImage reads the shared cache, so posters do not download again.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = .black
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
        }
    }
}
