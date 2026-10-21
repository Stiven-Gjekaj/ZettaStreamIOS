import SwiftUI
import ZettaCore

struct EditProfileScreen: View {
    let id: String?
    @EnvironmentObject private var app: AppModel

    var body: some View {
        EmptyMessage(text: "EditProfileScreen")
    }
}
