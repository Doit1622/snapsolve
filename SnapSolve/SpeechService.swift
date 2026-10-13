import AVFoundation

/// Liest Text vor und wartet, bis die Ausgabe fertig ist.
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private let lock = NSLock()

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        // .playback spricht auch bei aktiviertem Stummschalter, .duckOthers dämpft andere Audio-Apps.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    func speak(_ text: String, rate: Float, language: String = "de-DE") async {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = rate

        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            lock.lock()
            continuation = c
            lock.unlock()
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        let pending = takeContinuation()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        pending?.resume()
    }

    private func takeContinuation() -> CheckedContinuation<Void, Never>? {
        lock.lock()
        defer { lock.unlock() }
        let c = continuation
        continuation = nil
        return c
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        takeContinuation()?.resume()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        takeContinuation()?.resume()
    }
}
