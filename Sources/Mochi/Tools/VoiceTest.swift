#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Developer helper: `Mochi --voice-test` speaks a few sentences into sound files with the system voice
/// (`say` on the Mac, System.Speech on Windows), plays them through the real speech engine exactly as if
/// they came from the microphone, and checks what was understood. Everything runs on this computer.
/// `--allow-skip` passes when the computer has no speech recogniser at all (a bare CI machine).
enum VoiceTest {
    static func run(_ args: [String]) -> Never {
        _ = NSApplication.shared
        #if os(macOS)
        setvbuf(stdout, nil, _IOLBF, 0)            // line by line, so progress shows while it runs
        #endif
        let allowSkip = args.contains("--allow-skip")
        // A run loop with nothing attached returns at once without running work sent to the main queue
        // (where the engines report): keep a timer on it while the test waits.
        RunLoop.main.add(Timer(timeInterval: 0.02, repeats: true) { _ in }, forMode: .default)
        var failures = 0
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if !ok { failures += 1 }
            print("\(ok ? "PASS" : "FAIL")  \(name)\(detail.isEmpty ? "" : "  [\(detail)]")")
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mochi-voice-test-\(ProcessInfo.processInfo.processIdentifier)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        /// Runs the engine over `sentence` and returns every event, stopping at a result or after `seconds`.
        func listen(_ sentence: String, wake: Bool, seconds: TimeInterval = 25) -> [VoiceEvent] {
            #if os(macOS)
            let file = dir.appendingPathComponent("\(abs(sentence.hashValue)).aiff")
            #else
            let file = dir.appendingPathComponent("\(abs(sentence.hashValue)).wav")
            #endif
            guard synthesize(sentence, to: file) else {
                if allowSkip { print("SKIP  this computer has no voice to make the test recordings with"); exit(0) }
                print("FAIL  couldn't make a recording of \"\(sentence)\""); failures += 1; return []
            }
            let engine = VoiceControl.makeEngine()
            var events: [VoiceEvent] = []
            var done = false
            engine.onEvent = { e in
                events.append(e)
                switch e {
                case .heard, .failed: done = true
                case .nothing: done = !wake
                default: break
                }
            }
            if wake { engine.startWake(name: "Mochi", source: .file(file)) } else { engine.listenOnce(name: "Mochi", source: .file(file)) }
            let until = Date().addingTimeInterval(seconds)
            while !done, Date() < until { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            engine.stop()
            print("      \"\(sentence)\" → \(events.map(describe).joined(separator: ", "))")
            if case .failed(let why)? = events.last {
                if allowSkip { print("SKIP  no speech recognition here: \(why)"); exit(0) }
                print("FAIL  speech recognition isn't working: \(why)")
                exit(1)
            }
            return events
        }
        func heard(_ events: [VoiceEvent]) -> String {
            for e in events { if case .heard(let t) = e { return t.lowercased() } }
            return ""
        }

        if let i = args.firstIndex(of: "--live") { live(seconds: args.indices.contains(i + 1) ? Double(args[i + 1]) ?? 30 : 30) }

        print("--- Hey Mochi ---")
        let one = listen("Hey Mochi, do a dance.", wake: true)
        check("the wake phrase is heard", one.contains(.wake))
        check("the request after it is understood", heard(one).contains("dance"), heard(one))
        check("…and the pet knows what to do without AI", LocalCommands.match(heard(one))?.action == "dance")

        let two = listen("Hey Mochi. Can I give you a treat?", wake: true)
        check("a request after a pause is understood", two.contains(.wake) && heard(two).contains("treat"), heard(two))

        let three = listen("I had some mochi ice cream for lunch today.", wake: true, seconds: 12)
        check("talking about mochi doesn't wake the pet", !three.contains(.wake) && heard(three).isEmpty)

        print("--- Talk to Mochi ---")
        let four = listen("Please go to sleep.", wake: false)
        check("a request is understood straight away", four.first == .ready && heard(four).contains("sleep"), heard(four))
        check("…and the pet knows what to do without AI", LocalCommands.match(heard(four))?.action == "sleep")

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }

    /// `--voice-test --live [seconds]`: listens for "Hey Mochi" on the microphone and prints what happens.
    static func live(seconds: TimeInterval) -> Never {
        let engine = VoiceControl.makeEngine()
        let began = Date()
        func stamp() -> String { String(format: "%5.1fs", Date().timeIntervalSince(began)) }
        engine.onEvent = { print(stamp(), "event:", describe($0)) }
        #if os(macOS)
        if let mac = engine as? MacSpeechEngine {
            mac.onMeter = { print(stamp(), $0) }
            if let r = MacSpeechEngine.makeRecognizer() {
                print("recogniser \(r.locale.identifier), available \(r.isAvailable), on-device \(r.supportsOnDeviceRecognition)")
            }
        }
        #endif
        print("Say \u{201C}Hey Mochi, do a dance\u{201D} (listening for \(Int(seconds))s)")
        engine.startWake(name: "Mochi", source: .microphone)
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        engine.stop()
        exit(0)
    }

    static func describe(_ e: VoiceEvent) -> String {
        switch e {
        case .ready: return "ready"
        case .wake: return "wake"
        case .partial(let t): return "partial(\(t))"
        case .heard(let t): return "heard(\(t))"
        case .nothing: return "nothing"
        case .failed(let t): return "failed(\(t))"
        }
    }

    static func synthesize(_ text: String, to url: URL) -> Bool {
        #if os(macOS)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        p.arguments = ["-o", url.path, text]
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
        #else
        return SAPISpeechEngine.synthesize(text, to: url)
        #endif
    }
}
