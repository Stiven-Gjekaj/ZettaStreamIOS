import SwiftUI
import ZettaCore

@main
struct ZettaStreamApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ZettaStream")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .foregroundStyle(.white)
        }
    }
}
