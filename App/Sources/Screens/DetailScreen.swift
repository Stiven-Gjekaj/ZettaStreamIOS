import SwiftUI
import ZettaCore

struct DetailScreen: View {
    let preview: MetaPreview
    @EnvironmentObject private var app: AppModel

    var body: some View {
        EmptyMessage(text: "DetailScreen")
    }
}
