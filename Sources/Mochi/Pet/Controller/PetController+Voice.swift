#if canImport(AppKit)
import AppKit
import Combine
#else
import AppKitLite
#endif

/// Talking to the pet. `VoiceControl` does the listening; the pet shows it in its bubble: that it is
/// listening, the words as they are recognised, then its answer (see `ask`).
extension PetController {
    func hear(_ e: VoiceEvent) {
        switch e {
        case .ready, .wake:
            touch()
            // Perk up: wake from a nap and stand still to listen.
            var busy = action == .sleep || action == .chase || action == .zoomies || action == .lookAround
            if case .walk = action { busy = true }
            if canAct, busy { apply(Decision(action: .idle, duration: 10)) }
            if action == .idle { remaining = max(remaining, 10) }
            say(e == .wake ? "👂 Yes?" : "👂 I'm listening…", force: true, seconds: 10)
        case .partial(let text):
            say("\u{201C}\(text.suffix(90))\u{201D}", force: true, seconds: 8)
        case .heard(let text):
            ask(text, spoken: true)
        case .nothing:
            say("I didn't catch that. 🤔", force: true, seconds: 4)
        case .failed(let why):
            say(why, force: true, seconds: 9)
        }
    }
}

extension VoiceControl {
    /// Connects the voice to `pet` (the main one) and to the settings, on both platforms: answers appear in
    /// its bubble, "Hey <name>" follows the setting and the pet's name, and (with "Stay quiet during calls"
    /// on) nothing listens during a call.
    func attach(to pet: PetController, _ cancellables: inout Set<AnyCancellable>) {
        onEvent = { [weak pet] e in pet?.hear(e) }
        let s = PetSettings.shared
        // @Published sends the new value before the property changes: use the value it sends.
        s.$voiceWake.receive(on: DispatchQueue.main).sink { [weak self] on in
            self?.setWake(on, name: s.species.name)
        }.store(in: &cancellables)
        s.$species.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] species in
            self?.setWake(s.voiceWake, name: species.name)
        }.store(in: &cancellables)
        NotificationCenter.default.addObserver(forName: .mochiMediaChanged, object: nil, queue: .main) { [weak self] _ in
            self?.call(AudioWatcher.shared.onCall, quiet: s.quietOnCalls)
        }
        s.$quietOnCalls.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] quiet in
            self?.call(AudioWatcher.shared.onCall, quiet: quiet)
        }.store(in: &cancellables)
    }
}
