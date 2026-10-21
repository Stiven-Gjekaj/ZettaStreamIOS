import AVFoundation
import Speech
import SwiftUI

/// Listens for a title with the speech service of the device, as the Voice button of the
/// Android app does. The words show while the viewer talks. A pause of 1.5 seconds, the
/// end of the speech, or a second tap on the button stops the listening.
@MainActor
final class VoiceSearch: ObservableObject {
    @Published private(set) var listening = false
    /// The words so far.
    @Published private(set) var words = ""

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silence: Task<Void, Never>?
    private var finish: ((String) -> Void)?

    /// Starts to listen. `onWords` gets the words so far, and `onEnd` gets the last words,
    /// which can be empty. `onError` gets a message for the viewer.
    func start(onWords: @escaping (String) -> Void, onEnd: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        guard !listening else { return }
        Task {
            guard await Self.allowed() else {
                onError("Voice search needs the microphone and speech recognition. Allow them in Settings.")
                return
            }
            guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
                onError("Voice search is not available on this device")
                return
            }
            do {
                try begin(recognizer, onWords: onWords)
                finish = onEnd
            } catch {
                stop()
                onError("Voice search is not available on this device")
            }
        }
    }

    /// Stops the listening and gives the words to `onEnd`.
    func stop() {
        guard listening || request != nil else { return }
        silence?.cancel()
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let wasListening = listening
        listening = false
        let end = finish
        finish = nil
        if wasListening { end?(words.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func begin(_ recognizer: SFSpeechRecognizer, onWords: @escaping (String) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        words = ""

        Self.feed(engine.inputNode, to: request)
        engine.prepare()
        try engine.start()
        listening = true
        waitForSilence()

        task = Self.recognize(recognizer, request) { [weak self] text, done in
            guard let self, self.listening else { return }
            if let text {
                self.words = text
                onWords(text)
                self.waitForSilence()
            }
            if done { self.stop() }
        }
    }

    // The two calls below run on a thread of the audio or of the speech service. They are not
    // isolated to the main actor, because Swift then stops the app when they run on another thread.

    private nonisolated static func feed(_ input: AVAudioInputNode, to request: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    /// `update` gets the words so far, and true when the speech or the service stops.
    private nonisolated static func recognize(
        _ recognizer: SFSpeechRecognizer, _ request: SFSpeechAudioBufferRecognitionRequest,
        update: @escaping @MainActor (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let done = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in update(text, done) }
        }
    }

    /// Stops after 1.5 seconds with no new words. Each new word starts the time again.
    private func waitForSilence() {
        silence?.cancel()
        silence = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    private nonisolated static func allowed() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
}
