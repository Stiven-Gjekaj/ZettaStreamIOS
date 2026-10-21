import SwiftUI
import ZettaCore

struct StreamsScreen: View {
    let request: VideoRequest
    @EnvironmentObject private var app: AppModel

    var body: some View {
        EmptyMessage(text: "StreamsScreen")
    }
}
