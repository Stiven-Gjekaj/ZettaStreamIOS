import SwiftUI
import ZettaCore

@main
struct ZettaStreamApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ZettaStream")
                .font(Karla.font(34, .bold, relativeTo: .largeTitle))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zettaScreen()
        }
    }
}
