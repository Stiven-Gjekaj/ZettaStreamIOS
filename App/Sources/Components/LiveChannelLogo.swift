import SwiftUI
import ZettaCore

/// The logo of a channel. The first letters of the name show until the logo loads, or when it has no logo.
struct LiveChannelLogo: View {
    let channel: Channel

    var body: some View {
        ZStack {
            Palette.background
            if let logo = channel.logo, let url = URL(string: logo) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fit).padding(4)
                    default: initials
                    }
                }
            } else {
                initials
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Text(String(channel.name.prefix(3)))
            .font(Karla.font(14))
            .foregroundStyle(Palette.textSecondary)
    }
}
