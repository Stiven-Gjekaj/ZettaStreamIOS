import SwiftUI
import ZettaCore

/// The touch controls over the video: the title, the buttons, the seek bar, and the error.
struct PlayerControls: View {
    @ObservedObject var controller: PlayerController
    let subtitle: String
    let onClose: () -> Void
    let onOptions: () -> Void
    @State private var scrub: Double?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 12)
            centre
            Spacer(minLength: 12)
            bottomBar
        }
        .background {
            LinearGradient(colors: [.black.opacity(0.7), .clear, .clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 16) {
            RoundButton(icon: "xmark", label: "Close", action: onClose)
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.title)
                    .font(Karla.font(20, .bold))
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Karla.font(14))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if controller.pictureInPicturePossible {
                RoundButton(icon: "pip.enter", label: "Picture in Picture") { controller.togglePictureInPicture() }
            }
            RoundButton(icon: "slider.horizontal.3", label: "Options", action: onOptions)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var centre: some View {
        HStack(spacing: 36) {
            if controller.hasEpisodes {
                RoundButton(icon: "backward.end.fill", label: controller.isLive ? "Previous channel" : "Previous episode") {
                    controller.changeEpisode(-1)
                }
            }
            if !controller.isLive {
                RoundButton(icon: "gobackward.10", label: "Back 10 seconds") { controller.seek(by: -PlayerController.seekStep) }
            }
            Button { controller.togglePlay() } label: {
                Image(systemName: controller.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .frame(width: 76, height: 76)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel(controller.playing ? "Pause" : "Play")
            if !controller.isLive {
                RoundButton(icon: "goforward.10", label: "Forward 10 seconds") { controller.seek(by: PlayerController.seekStep) }
            }
            if controller.hasEpisodes {
                RoundButton(icon: "forward.end.fill", label: controller.isLive ? "Next channel" : "Next episode") {
                    controller.changeEpisode(1)
                }
            }
        }
        .foregroundStyle(Palette.textPrimary)
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = controller.error {
                Text(error)
                    .font(Karla.font(15))
                    .foregroundStyle(Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                if !controller.isLive {
                    Button("Choose another source") { controller.chooseSource() }
                        .buttonStyle(.zPrimary)
                }
            }
            if !controller.isLive && controller.duration > 0 {
                HStack(spacing: 12) {
                    Text(Timing.formatTime(Int(scrub ?? Double(controller.position))))
                        .monospacedDigit()
                    Slider(value: Binding(get: { scrub ?? Double(controller.position) }, set: { scrub = $0 }),
                           in: 0...Double(max(controller.duration, 1))) { editing in
                        controller.showOverlay()
                        if !editing, let target = scrub {
                            controller.seek(to: Int(target))
                            scrub = nil
                        }
                    }
                    .tint(Palette.accent)
                    Text(Timing.formatTime(controller.duration))
                        .monospacedDigit()
                    Button(controller.skipButtonLabel) { controller.skip() }
                        .buttonStyle(.zSecondary)
                }
                .font(Karla.font(14))
                .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

/// A round icon button of the player.
struct RoundButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.45), in: Circle())
        }
        .foregroundStyle(Palette.textPrimary)
        .accessibilityLabel(label)
    }
}

/// The card of the next episode countdown, and the skip prompt. They show also with no controls.
struct PlayerPrompts: View {
    @ObservedObject var controller: PlayerController

    var body: some View {
        if let left = controller.countdownLeft {
            VStack(alignment: .leading, spacing: 10) {
                Text("Next episode in \(left) s")
                    .font(Karla.font(18, .semibold))
                HStack(spacing: 10) {
                    Button("Play now") { controller.playNextNow() }
                        .buttonStyle(.zPrimary)
                    Button("Cancel") { controller.cancelCountdown() }
                        .buttonStyle(.zSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
        } else if let prompt = controller.skipPrompt {
            Button(prompt) { controller.skip() }
                .buttonStyle(.zPrimary)
        }
    }
}
