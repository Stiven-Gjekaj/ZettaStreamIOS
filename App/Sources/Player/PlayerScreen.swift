import SwiftUI
import ZettaCore

/// The player. It covers the full screen in landscape. A tap shows or hides the controls,
/// and a double tap on the left or the right side goes 10 seconds back or forward.
struct PlayerScreen: View {
    let playback: Playback
    @EnvironmentObject private var app: AppModel
    @StateObject private var controller: PlayerController
    @State private var optionsOpen = false
    @State private var inputs = PlayerInputs()
    @State private var keys: PlayerKeyActions?

    init(playback: Playback) {
        self.playback = playback
        _controller = StateObject(wrappedValue: PlayerController(playback: playback))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerKeyCatcher { key, pressed in keys?.handle(key, pressed: pressed) }
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            PlayerVideoView(surface: controller.surface)
                .ignoresSafeArea()
            if controller.settings.sideBars == .ambient {
                AmbientFillView(image: controller.ambient, picture: controller.videoRect)
                    .ignoresSafeArea()
            }
            FilterOverlayView(filter: controller.settings.videoFilter)
                .ignoresSafeArea()
            // The small window shows only the video.
            if !controller.pictureInPictureActive { layers }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("player")
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .zettaScreen()
        .onAppear {
            controller.start(app: app)
            startKeys()
        }
        .onDisappear {
            inputs.stop()
            keys?.stop()
            controller.close()
        }
    }

    @ViewBuilder
    private var layers: some View {
        tapZones
        if controller.buffering && controller.error == nil {
            VStack(spacing: 16) {
                ProgressView().controlSize(.large).tint(Palette.accent)
                if let text = controller.torrentText {
                    Text(text).font(Karla.font(15)).foregroundStyle(Palette.textSecondary)
                }
            }
            .allowsHitTesting(false)
        }
        if controller.overlayVisible || controller.error != nil {
            PlayerControls(controller: controller, subtitle: controller.subtitle(guide: app.live.guide),
                           onClose: close, onOptions: openOptions)
                .transition(.opacity)
        } else if controller.labelVisible, let label = controller.video?.sourceLabel {
            // The stream that plays: at the start, and each time the controls show.
            sourceLabel(label)
        }
        PlayerPrompts(controller: controller)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 24)
            .padding(.bottom, controller.overlayVisible ? 96 : 32)
        if let message = controller.message {
            Text(message)
                .font(Karla.font(17))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: corner))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 80)
                .padding(.trailing, 24)
                .allowsHitTesting(false)
        }
        if optionsOpen {
            HStack(spacing: 0) {
                Color.black.opacity(0.001).onTapGesture { optionsOpen = false }
                PlayerOptionsSheet(controller: controller) { optionsOpen = false }
                    .frame(width: 440)
                    .ignoresSafeArea(edges: .vertical)
            }
            .transition(.move(edge: .trailing))
        }
    }

    /// Two halves of the screen. A single tap waits a moment, to tell it from a double tap.
    private var tapZones: some View {
        HStack(spacing: 0) {
            zone(step: -PlayerController.seekStep)
            zone(step: PlayerController.seekStep)
        }
        .ignoresSafeArea()
    }

    private func zone(step: Int) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                controller.seek(by: step)
                if !controller.isLive { controller.show(step > 0 ? "+10 s" : "-10 s") }
            }
            .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { controller.toggleOverlay() } }
    }

    private func sourceLabel(_ text: String) -> some View {
        Text(text)
            .font(Karla.font(13))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: corner))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .allowsHitTesting(false)
    }

    /// A keyboard and a game controller work as the remote control of the Android app.
    private func startKeys() {
        let actions = PlayerKeyActions(
            controller: controller,
            optionsOpen: { optionsOpen },
            setOptions: { open in
                if open { openOptions() } else { withAnimation(.easeOut(duration: 0.2)) { optionsOpen = false } }
            },
            close: close)
        keys = actions
        inputs.start { key, pressed in actions.handle(key, pressed: pressed) }
    }

    private func openOptions() {
        controller.showOverlay()
        withAnimation(.easeOut(duration: 0.2)) { optionsOpen = true }
    }

    private func close() {
        controller.saveProgress()
        app.closePlayer()
    }
}
