import SwiftUI

/// An image from a URL. The images stay in the shared URL cache, which the app makes large at start.
struct RemoteImage: View {
    let url: String?
    var contentMode: ContentMode = .fill

    var body: some View {
        if let url, let address = URL(string: url) {
            AsyncImage(url: address, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image): image.resizable().aspectRatio(contentMode: contentMode)
                default: Palette.surfaceHigh
                }
            }
        } else {
            Palette.surfaceHigh
        }
    }
}
