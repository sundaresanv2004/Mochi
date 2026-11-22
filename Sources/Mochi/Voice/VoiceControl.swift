import Foundation

/// What a speech engine reports, always on the main thread.
enum VoiceEvent: Equatable {
    case ready                  // listening for a request now
    case wake                   // heard "Hey <name>": listening for the request that follows
    case partial(String)        // the request so far, while it is being said
    case heard(String)          // the whole request
    case nothing                // listened, but no request came
    case failed(String)         // can't listen (no permission, no recogniser); says why, for the bubble
}

/// Where an engine gets its sound: the microphone, or (for `--voice-test`) a recording.
enum VoiceSource {
    case microphone
    case file(URL)
}

/// A speech recogniser for one platform. Both run entirely on this computer: the Mac's on-device
/// speech recognition, and the Windows desktop speech recogniser (SAPI).
protocol SpeechEngine: AnyObject {
    var onEvent: ((VoiceEvent) -> Void)? { get set }
    /// Listen for one request right away.
    func listenOnce(name: String, source: VoiceSource)
    /// Keep listening for "Hey <name>", then for the request after it, until `stop`.
    func startWake(name: String, source: VoiceSource)
    func stop()
}

/// Talking to the pet: "Talk to Mochi" in the menu listens once; with the setting on, saying
/// "Hey Mochi" works at any time. Whatever is heard is handed to the pet like a typed request.
final class VoiceControl {
    static let shared = VoiceControl()

    /// Every event, for the pet to show in its bubble.
    var onEvent: ((VoiceEvent) -> Void)?

    private let engine: SpeechEngine
    private var wakeWanted = false
    private var name = "Mochi"
    private var blocks = Set<String>()
    private var oneShot = false
    private(set) var wakeRunning = false

    static func makeEngine() -> SpeechEngine {
        #if os(macOS)
        return MacSpeechEngine()
        #else
        return SAPISpeechEngine()
        #endif
    }

    /// `engine` is for the logic test; the app uses the platform's own.
    init(engine: SpeechEngine? = nil) { self.engine = engine ?? VoiceControl.makeEngine() }

    /// Listen for one request now (from the menu). Wake listening pauses meanwhile.
    func listenOnce(name: String) {
        self.name = name
        stopWake()
        oneShot = true
        engine.onEvent = { [weak self] e in self?.handle(e) }
        engine.listenOnce(name: name, source: .microphone)
    }

    /// Listen for "Hey <name>" from now on (or stop).
    func setWake(_ on: Bool, name: String) {
        let renamed = name != self.name
        wakeWanted = on
        self.name = name
        if renamed { stopWake() }
        refresh()
    }

    /// While any reason is set (the computer sleeping, a call, the screen locked) nothing listens.
    func block(_ reason: String) { blocks.insert(reason); refresh() }
    func unblock(_ reason: String) { blocks.remove(reason); refresh() }

    /// A call pauses "Hey <name>" only while "Stay quiet during calls" is on; with it off, the pet keeps listening.
    func call(_ onCall: Bool, quiet: Bool) {
        if onCall && quiet { block("call") } else { unblock("call") }
    }

    private func refresh() {
        guard !oneShot else { return }                 // picks up again when the one-off request is done
        let should = wakeWanted && blocks.isEmpty
        if should, !wakeRunning {
            wakeRunning = true
            engine.onEvent = { [weak self] e in self?.handle(e) }
            engine.startWake(name: name, source: .microphone)
        } else if !should, wakeRunning {
            stopWake()
        }
    }

    private func stopWake() {
        guard wakeRunning else { return }
        wakeRunning = false
        engine.stop()
    }

    private func handle(_ e: VoiceEvent) {
        switch e {
        case .heard, .nothing, .failed:
            if oneShot {
                oneShot = false
                engine.stop()
                refresh()
            } else if case .failed = e {
                // Wake listening can't work (permission refused, no recogniser): switch it off rather than retry forever.
                wakeRunning = false
                wakeWanted = false
                engine.stop()
                if self === VoiceControl.shared, PetSettings.shared.voiceWake { PetSettings.shared.voiceWake = false }
            }
        default: break
        }
        // Engines report after updating their own state, so starting or stopping them from here is safe.
        onEvent?(e)
    }
}
