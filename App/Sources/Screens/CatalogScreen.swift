import SwiftUI
import ZettaCore

struct CatalogScreen: View {
    let row: CatalogRow
    @EnvironmentObject private var app: AppModel

    var body: some View {
        EmptyMessage(text: "CatalogScreen")
    }
}
