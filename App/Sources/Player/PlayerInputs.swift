import GameController
import SwiftUI
import UIKit
import ZettaCore

/// Gets the keys of a hardware keyboard while the player shows. UIKit gives each key press to
/// the first responder, so this view takes that place. GameController does not get the keys of
/// every keyboard, such as the keys of the simulator.
struct PlayerKeyCatcher: UIViewRepresentable {
    let onKey: (PlayerKey, Bool) -> Void

    func makeUIView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onKey = onKey
        return view
    }

    func updateUIView(_ view: CatcherView, context: Context) {
        view.onKey = onKey
        // A sheet or a button can take the first responder. The view takes it back.
        if view.window != nil && !view.isFirstResponder { view.becomeFirstResponder() }
    }

    final class CatcherView: UIView {
        var onKey: ((PlayerKey, Bool) -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { DispatchQueue.main.async { [weak self] in self?.becomeFirstResponder() } }
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if !send(presses, pressed: true) { super.pressesBegan(presses, with: event) }
        }

        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if !send(presses, pressed: false) { super.pressesEnded(presses, with: event) }
        }

        override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if !send(presses, pressed: false) { super.pressesCancelled(presses, with: event) }
        }

        /// True when a press is a key of the player. A key with Command goes on to the app.
        private func send(_ presses: Set<UIPress>, pressed: Bool) -> Bool {
            var used = false
            for press in presses {
                guard let key = press.key, !key.modifierFlags.contains(.command),
                      let action = PlayerKeys.keyboard(key.keyCode.rawValue) else { continue }
                onKey?(action, pressed)
                used = true
            }
            return used
        }
    }
}

/// Reads the buttons of game controllers while the player shows, and gives each press and
/// each release as a `PlayerKey`. The keys of a keyboard come through `PlayerKeyCatcher`.
@MainActor
final class PlayerInputs {
    private var observers: [NSObjectProtocol] = []
    private var onKey: ((PlayerKey, Bool) -> Void)?

    /// Starts to read. `onKey` gets the key and true for a press, false for a release.
    func start(_ onKey: @escaping (PlayerKey, Bool) -> Void) {
        stop()
        self.onKey = onKey
        let center = NotificationCenter.default
        for name in [Notification.Name.GCControllerDidConnect] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.connect() }
            })
        }
        connect()
        GCController.startWirelessControllerDiscovery()
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        onKey = nil
        for controller in GCController.controllers() {
            controller.extendedGamepad?.valueChangedHandler = nil
            Self.buttons(of: controller).forEach { $0.0.pressedChangedHandler = nil }
        }
        GCController.stopWirelessControllerDiscovery()
    }

    private func connect() {
        let send: @Sendable (PlayerKey, Bool) -> Void = { [weak self] key, pressed in
            Task { @MainActor in self?.onKey?(key, pressed) }
        }
        for controller in GCController.controllers() { Self.listen(controller: controller, send) }
    }

    // The handlers below are not isolated to the main actor. GameController can call them on
    // another queue, and Swift then stops the app for a handler of the main actor.

    private nonisolated static func listen(controller: GCController, _ send: @escaping @Sendable (PlayerKey, Bool) -> Void) {
        for (input, button) in buttons(of: controller) {
            input.pressedChangedHandler = { _, _, pressed in send(PlayerKeys.controller(button), pressed) }
        }
    }

    private nonisolated static func buttons(of controller: GCController) -> [(GCControllerButtonInput, ControllerButton)] {
        guard let pad = controller.extendedGamepad else { return [] }
        var list: [(GCControllerButtonInput, ControllerButton)] = [
            (pad.buttonA, .a), (pad.buttonB, .b), (pad.buttonX, .x), (pad.buttonY, .y),
            (pad.leftShoulder, .leftShoulder), (pad.rightShoulder, .rightShoulder),
            (pad.dpad.left, .left), (pad.dpad.right, .right), (pad.dpad.up, .up), (pad.dpad.down, .down),
            (pad.buttonMenu, .menu),
        ]
        if let options = pad.buttonOptions { list.append((options, .options)) }
        return list
    }
}

/// Does the action of each player key: the rules of the remote control of the Android app.
/// A held Left or Right seeks again and farther. OK acts when it comes up, so that a long press
/// can open the options in its place.
@MainActor
final class PlayerKeyActions {
    private let controller: PlayerController
    private let optionsOpen: () -> Bool
    private let setOptions: (Bool) -> Void
    private let close: () -> Void
    private var repeatTask: Task<Void, Never>?
    private var longPressTask: Task<Void, Never>?
    private var selectUsed = false

    init(controller: PlayerController, optionsOpen: @escaping () -> Bool, setOptions: @escaping (Bool) -> Void, close: @escaping () -> Void) {
        self.controller = controller
        self.optionsOpen = optionsOpen
        self.setOptions = setOptions
        self.close = close
    }

    func handle(_ key: PlayerKey, pressed: Bool) {
        if !pressed {
            if key == .left || key == .right { repeatTask?.cancel() }
            if key == .select { releaseSelect() }
            return
        }
        if optionsOpen() {
            // The options sheet takes touches. Back, Options, and 0 close it, as on Android.
            if key == .back || key == .options { setOptions(false) }
            return
        }
        if controller.countdownLeft != nil {
            switch key {
            case .select: selectUsed = true; return controller.playNextNow()
            case .back: return controller.cancelCountdown()
            default: break
            }
        }
        switch key {
        case .select:
            selectUsed = false
            longPressTask?.cancel()
            longPressTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(PlayerKeys.longPress * 1e9))
                guard let self, !Task.isCancelled else { return }
                self.selectUsed = true
                self.controller.showOverlay()
                self.setOptions(true)
            }
        case .back: close()
        case .left, .right: startSeek(key)
        case .up, .down, .info: controller.showOverlay()
        case .options:
            controller.showOverlay()
            setOptions(true)
        case .playPause: controller.togglePlay()
        case .next: controller.changeEpisode(1)
        case .previous: controller.changeEpisode(-1)
        case .subtitles: controller.cycleSubtitle()
        case .audio: controller.cycleAudio()
        case .skip: if !controller.isLive { controller.skip() }
        case .number(let number):
            guard !controller.isLive, let target = PlayerKeys.position(number: number, duration: controller.duration) else { return }
            controller.seek(to: target)
            controller.show("\(number * 10)%")
        }
    }

    func stop() {
        repeatTask?.cancel()
        longPressTask?.cancel()
    }

    private func releaseSelect() {
        longPressTask?.cancel()
        guard !selectUsed else { return }
        selectUsed = true
        // While a skip prompt shows, OK skips, as on the large streaming services.
        if controller.skipPrompt != nil { controller.skip() } else { controller.togglePlay() }
    }

    private func startSeek(_ key: PlayerKey) {
        repeatTask?.cancel()
        seek(key, repeated: false)
        repeatTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(PlayerKeys.repeatDelay * 1e9))
            while !Task.isCancelled {
                self?.seek(key, repeated: true)
                try? await Task.sleep(nanoseconds: UInt64(PlayerKeys.repeatInterval * 1e9))
            }
        }
    }

    private func seek(_ key: PlayerKey, repeated: Bool) {
        guard let step = PlayerKeys.seek(key, repeated: repeated) else { return }
        if controller.isLive { return controller.showOverlay() }
        controller.seek(by: step)
    }
}
