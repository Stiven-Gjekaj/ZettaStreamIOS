import SwiftUI
import ZettaCore

struct PlayerScreen: View {
    let playback: Playback
    @EnvironmentObject private var app: AppModel

    var body: some View {
        EmptyMessage(text: "PlayerScreen")
    }
}
