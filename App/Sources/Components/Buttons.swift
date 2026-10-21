import SwiftUI

/// The white button of the app. A secondary button has a dark fill.
struct ZButtonStyle: ButtonStyle {
    var primary = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Karla.font(15, .bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .foregroundStyle(primary ? Palette.onAccent : Palette.textPrimary)
            .background(primary ? Palette.accent : Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(primary ? .clear : Palette.outline))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == ZButtonStyle {
    static var zPrimary: ZButtonStyle { ZButtonStyle(primary: true) }
    static var zSecondary: ZButtonStyle { ZButtonStyle(primary: false) }
}

/// The title of a row or a section.
struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Karla.font(18, .bold, relativeTo: .headline))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A grey line of text in the middle of an empty screen.
struct EmptyMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Karla.font(15))
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
