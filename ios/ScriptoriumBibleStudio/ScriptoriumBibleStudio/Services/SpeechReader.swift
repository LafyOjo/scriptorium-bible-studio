import AVFoundation
import Foundation

final class SpeechReader: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum State {
        case stopped
        case speaking
        case paused
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var currentRange: NSRange?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start(text: String, rate: Float = 0.48) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        state = .speaking
    }

    func pause() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
    }

    func resume() {
        guard synthesizer.isPaused else { return }
        synthesizer.continueSpeaking()
        state = .speaking
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        state = .stopped
        currentRange = nil
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        currentRange = characterRange
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        state = .stopped
        currentRange = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        state = .stopped
        currentRange = nil
    }
}
