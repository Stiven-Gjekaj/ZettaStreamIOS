import SwiftUI
import ZettaCore

struct AutoPlayScreen: View {
    let request: VideoRequest
    @EnvironmentObject private var app: AppModel

    var body: some View {
        EmptyMessage(text: "AutoPlayScreen")
    }
}
