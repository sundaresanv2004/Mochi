#if os(macOS)
import AVFoundation
import Foundation
import Speech

/// Speech recognition on the Mac, done on the device (`requiresOnDeviceRecognition`) whenever the
/// Mac has the speech model for your language, so nothing you say leaves the Mac.
///
/// Listening for "Hey Mochi" keeps the microphone open but not the recogniser: a simple loudness gate
/// watches the sound, and only when someone starts speaking is that snippet (with the half second
/// before it) given to the recogniser. If it starts with the wake phrase, the rest of what is said is
/// the request; anything else is thrown away.
final class MacSpeechEngine: SpeechEngine {
    var onEvent: ((VoiceEvent) -> Void)?
    /// For `--voice-test --live`: once a second, the loudness, the gate's threshold and the phase.
    var onMeter: ((String) -> Void)?
    private var meterAt: TimeInterval = 0
    private var meterPeak: Float = -120

    private enum Mode { case off, wake, command }
    private enum Phase { case waiting, snippet, request }

    private let audio = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var mode = Mode.off
    private var name = "Mochi"
    private var session = 0                  // ignores callbacks from a recognition task that was replaced
    private var run = 0                      // ignores callbacks from a start that was stopped since
    /// The current snippet started with the wake phrase (read by the audio thread too, so set under `lock`).
    private var wakeHeard: Bool {
        get { lock.lock(); defer { lock.unlock() }; return gateWake }
        set { lock.lock(); gateWake = newValue; lock.unlock() }
    }
    private var lastText = ""
    private var tapInstalled = false
    private var fileThread: Thread?
    private var configObserver: NSObjectProtocol?

    // Shared with the audio thread, under `lock`.
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var phase = Phase.waiting
    private var preRoll: [AVAudioPCMBuffer] = []
    private var preRollFrames: AVAudioFrameCount = 0
    private var noiseFloor: Float = -55
    private var phaseStarted: TimeInterval = 0
    private var lastLoud: TimeInterval = 0
    private var spoke = false
    private var ending = false
    private var starting = false
    private var clock: TimeInterval = 0      // seconds of sound seen, from the buffers themselves
    private var gateWake = false

    // MARK: SpeechEngine

    func listenOnce(name: String, source: VoiceSource) {
        begin(.command, name: name, source: source)
    }

    func startWake(name: String, source: VoiceSource) {
        begin(.wake, name: name, source: source)
    }

    func stop() {
        session += 1
        run += 1
        mode = .off
        task?.cancel()
        task = nil
        lock.lock()
        request?.endAudio()
        request = nil
        phase = .waiting
        preRoll = []; preRollFrames = 0
        lock.unlock()
        fileThread?.cancel()
        fileThread = nil
        if tapInstalled { audio.inputNode.removeTap(onBus: 0); tapInstalled = false }
        audio.stop()
        if let o = configObserver { NotificationCenter.default.removeObserver(o); configObserver = nil }
    }

    // MARK: Starting

    private func begin(_ m: Mode, name: String, source: VoiceSource) {
        stop()
        self.name = name
        mode = m
        let token = run
        Self.authorize { [weak self] problem in
            guard let self, self.run == token else { return }
            if let problem { self.mode = .off; self.emit(.failed(problem)); return }
            guard let r = Self.makeRecognizer(), r.isAvailable else {
                self.mode = .off
                self.emit(.failed("Speech recognition isn't available for your language on this Mac."))
                return
            }
            // Listening all the time is only done on the device; a one-off request may use Apple's servers
            // if this Mac has no on-device model for the language.
            if m == .wake, !r.supportsOnDeviceRecognition {
                self.mode = .off
                self.emit(.failed("Listening for \u{201C}Hey \(name)\u{201D} needs on-device speech recognition. Turn on Dictation in System Settings › Keyboard to download it."))
                return
            }
            self.recognizer = r
            self.resetGate()
            if m == .command { self.startRequest(phase: .request) }
            switch source {
            case .microphone: self.startMicrophone()
            case .file(let url): self.startFile(url)
            }
        }
    }

    static func makeRecognizer() -> SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// Asks for speech recognition and microphone access the first time; nil when both are allowed.
    static func authorize(_ done: @escaping (String?) -> Void) {
        func mic() {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: done(nil)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { ok in
                    DispatchQueue.main.async { done(ok ? nil : micRefused) }
                }
            default: done(micRefused)
            }
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: mic()
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async { status == .authorized ? mic() : done(speechRefused) }
            }
        default: done(speechRefused)
        }
    }

    private static let micRefused = "I can't hear you. Allow Mochi in System Settings › Privacy & Security › Microphone."
    private static let speechRefused = "I can't understand speech yet. Allow Mochi in System Settings › Privacy & Security › Speech Recognition."

    private func startMicrophone() {
        let input = audio.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            mode = .off
            emit(.failed("I can't find a microphone."))
            return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.feed(buffer)
        }
        tapInstalled = true
        audio.prepare()
        do {
            try audio.start()
        } catch {
            stop()
            emit(.failed("I can't hear you: the microphone wouldn't start."))
            return
        }
        // Headphones plugged in or out: the input changes format, so start again on the new one.
        let token = run, m = mode, n = name
        configObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: audio, queue: .main) { [weak self] _ in
            guard let self, self.run == token else { return }
            self.begin(m, name: n, source: .microphone)
        }
        if mode == .command { emit(.ready) }
    }

    /// Plays a recording through the same path as the microphone, at its real speed, then a little silence.
    private func startFile(_ url: URL) {
        guard let file = try? AVAudioFile(forReading: url) else {
            emit(.failed("Couldn't open \(url.lastPathComponent)."))
            return
        }
        if mode == .command { emit(.ready) }
        let format = file.processingFormat
        let t = Thread { [weak self] in
            let chunk: AVAudioFrameCount = 1024
            let seconds = Double(chunk) / format.sampleRate
            var silence = Int(3 / seconds)
            while !Thread.current.isCancelled {
                guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { break }
                if (try? file.read(into: buf, frameCount: chunk)) == nil || buf.frameLength == 0 {
                    guard silence > 0 else { break }
                    silence -= 1
                    buf.frameLength = chunk          // zeroed: silence after the recording
                    if let d = buf.floatChannelData { for c in 0..<Int(format.channelCount) { memset(d[c], 0, Int(chunk) * 4) } }
                }
                self?.feed(buf)
                Thread.sleep(forTimeInterval: seconds)
            }
        }
        fileThread = t
        t.start()
    }

    // MARK: The loudness gate (audio thread)

    private func resetGate() {
        lock.lock()
        phase = .waiting
        preRoll = []; preRollFrames = 0
        spoke = false; ending = false; starting = false
        clock = 0; phaseStarted = 0; lastLoud = 0
        lock.unlock()
    }

    /// Loudness of a buffer in dBFS.
    static func level(_ b: AVAudioPCMBuffer) -> Float {
        guard let data = b.floatChannelData, b.frameLength > 0 else { return -120 }
        let n = Int(b.frameLength) * (b.format.isInterleaved ? Int(b.format.channelCount) : 1)
        var sum: Float = 0
        let p = data[0]
        for i in 0..<n { sum += p[i] * p[i] }
        let rms = (sum / Float(n)).squareRoot()
        return rms > 0 ? 20 * log10(rms) : -120
    }

    /// How loud counts as someone speaking: clearly above the room's own noise. Built-in Mac microphones are
    /// quiet (a still room reads about -70 dB, a voice across the desk -55 to -40 dB), so the bar sits low;
    /// a false start only costs a moment of recognition that finds no "Hey Mochi".
    static func threshold(_ noise: Float) -> Float { max(noise + 11, -60) }

    static func copy(_ b: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let c = AVAudioPCMBuffer(pcmFormat: b.format, frameCapacity: b.frameLength),
              let s = b.floatChannelData, let d = c.floatChannelData else { return nil }
        c.frameLength = b.frameLength
        let channels = b.format.isInterleaved ? 1 : Int(b.format.channelCount)
        let floats = Int(b.frameLength) * (b.format.isInterleaved ? Int(b.format.channelCount) : 1)
        for ch in 0..<channels { memcpy(d[ch], s[ch], floats * MemoryLayout<Float>.size) }
        return c
    }

    private func feed(_ buffer: AVAudioPCMBuffer) {
        let db = Self.level(buffer)
        var action: (() -> Void)?
        lock.lock()
        clock += Double(buffer.frameLength) / buffer.format.sampleRate
        let now = clock
        let loud = db > Self.threshold(noiseFloor)
        if loud { lastLoud = now }
        meterPeak = max(meterPeak, db)
        if let meter = onMeter, now - meterAt >= 1 {
            let line = String(format: "level peak %.0f dB, noise %.0f dB, speech above %.0f dB, %@", meterPeak, noiseFloor,
                              Self.threshold(noiseFloor), "\(phase)")
            meterAt = now; meterPeak = -120
            DispatchQueue.main.async { meter(line) }
        }

        switch phase {
        case .waiting:
            // Keep the last moment of sound, so the start of "hey" isn't lost while the recogniser starts.
            if let c = Self.copy(buffer) {
                preRoll.append(c); preRollFrames += c.frameLength
                while preRollFrames > AVAudioFrameCount(buffer.format.sampleRate * 0.7), preRoll.count > 1 {
                    preRollFrames -= preRoll.removeFirst().frameLength
                }
            }
            if !loud { noiseFloor = noiseFloor * 0.98 + db * 0.02 }
            if loud, mode == .wake, !starting {
                starting = true
                action = { [weak self] in self?.startRequest(phase: .snippet) }
            }
        case .snippet, .request:
            request?.append(buffer)
            if loud { spoke = true }
            let quietFor = now - lastLoud, length = now - phaseStarted
            // A wake snippet is short; a request may run longer and pause between words.
            let isRequest = phase == .request || gateWake
            let endAfter: TimeInterval = isRequest ? 1.4 : 0.9
            let longest: TimeInterval = isRequest ? 14 : 5
            let nothingSaid = phase == .request && !spoke && length > 7
            if !ending, (spoke && quietFor > endAfter) || length > longest || nothingSaid {
                ending = true
                action = { [weak self] in self?.endRequest() }
            }
        }
        lock.unlock()
        if let action { DispatchQueue.main.async(execute: action) }
    }

    // MARK: Recognition (main thread)

    private func startRequest(phase p: Phase) {
        guard mode != .off, let recognizer else { return }
        session += 1
        let token = session
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        req.contextualStrings = [name, "Hey \(name)"]
        req.taskHint = .dictation
        if p == .snippet { wakeHeard = false }
        lastText = ""
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.session == token else { return }
                if let result { self.got(result.bestTranscription.formattedString, final: result.isFinal, phase: p) }
                if error != nil, result?.isFinal != true { self.got(self.lastText, final: true, phase: p) }
            }
        }
        lock.lock()
        request = req
        if p == .snippet { for b in preRoll { req.append(b) } }
        preRoll = []; preRollFrames = 0
        phase = p
        phaseStarted = p == .snippet ? max(0, clock - 0.7) : clock
        lastLoud = clock
        spoke = p == .snippet
        ending = false
        starting = false
        lock.unlock()
    }

    private func endRequest() {
        lock.lock()
        let req = request
        request = nil
        lock.unlock()
        req?.endAudio()
    }

    private func got(_ text: String, final: Bool, phase p: Phase) {
        lastText = text
        if p == .snippet {
            if let rest = WakePhrase.command(in: text, name: name) {
                if !wakeHeard { wakeHeard = true; emit(.wake) }
                if !final, !rest.isEmpty { emit(.partial(rest)) }
                if final {
                    if rest.isEmpty {
                        startRequest(phase: .request)          // "Hey Mochi" … then the request
                    } else {
                        backToWaiting()
                        emit(.heard(rest))
                    }
                }
            } else if final {
                let wasCalled = wakeHeard
                backToWaiting()
                if wasCalled { emit(.nothing) }
            }
            return
        }
        // A request (listen once, or after "Hey Mochi" on its own).
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !final {
            if !clean.isEmpty { emit(.partial(clean)) }
            return
        }
        // The wake phrase said twice ("Hey Mochi… hey Mochi, dance") still gives just the request.
        let request = WakePhrase.command(in: clean, name: name) ?? clean
        if mode == .wake { backToWaiting() } else { mode = .off }
        emit(request.isEmpty ? .nothing : .heard(request))
    }

    private func backToWaiting() {
        task = nil
        session += 1
        wakeHeard = false
        lock.lock()
        request = nil
        phase = .waiting
        ending = false; starting = false; spoke = false
        lock.unlock()
    }

    private func emit(_ e: VoiceEvent) {
        if Thread.isMainThread { onEvent?(e) } else { DispatchQueue.main.async { self.onEvent?(e) } }
    }
}
#endif
