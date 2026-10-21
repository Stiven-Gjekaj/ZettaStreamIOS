import SwiftUI

/// A short message at the bottom of the screen. It goes away after a few seconds.
struct ToastView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        if let message = app.toast {
            Text(message)
                .font(Karla.font(15, .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
                .padding(.bottom, 72)
                .transition(.opacity)
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if app.toast == message { app.toast = nil }
                }
        }
    }
}
