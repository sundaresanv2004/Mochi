#if os(Windows)
import Foundation

/// Speech recognition on Windows with the desktop speech recogniser that ships with Windows
/// (System.Speech / SAPI). It runs entirely on the PC: nothing is sent anywhere.
///
/// It runs in a hidden Windows PowerShell (which has System.Speech built in), which prints one line per
/// event: `READY`, `WAKE <what was heard>`, `HEARD <request>`, `NOTHING`, `NORECOGNIZER` or `ERROR <why>`.
/// Listening for "Hey Mochi" uses a tiny grammar ("hey/hi/hello/okay Mochi", optionally followed by
/// free dictation), which the recogniser matches cheaply; free dictation only starts after it.
final class SAPISpeechEngine: SpeechEngine {
    var onEvent: ((VoiceEvent) -> Void)?

    private var process: HiddenProcess?
    private var session = 0
    private var pending = Data()
    private var mode = ""
    private var name = "Mochi"
    private var source = VoiceSource.microphone
    private var finished = false             // a one-off request already reported its result
    private var failures = 0

    func listenOnce(name: String, source: VoiceSource) { start("once", name: name, source: source) }
    func startWake(name: String, source: VoiceSource) { failures = 0; start("wake", name: name, source: source) }

    func stop() {
        session += 1
        process?.terminate()
        process = nil
        pending = Data()
    }

    private func start(_ mode: String, name: String, source: VoiceSource) {
        stop()
        self.mode = mode
        self.name = name
        self.source = source
        finished = false
        let token = session
        var wave = ""
        if case .file(let url) = source { wave = url.path }
        let p = HiddenProcess(executable: HiddenProcess.powershell,
                              arguments: ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                                          "-EncodedCommand", HiddenProcess.encode(Self.script(mode: mode, name: name, wave: wave))])
        p.onOutput = { [weak self] data in
            DispatchQueue.main.async { if self?.session == token { self?.receive(data) } }
        }
        p.onExit = { [weak self] in
            DispatchQueue.main.async { if self?.session == token { self?.exited() } }
        }
        process = p
        if !p.start() {
            process = nil
            emit(.failed("I couldn't start Windows speech recognition."))
        }
    }

    private func receive(_ data: Data) {
        pending.append(data)
        while let nl = pending.firstIndex(of: 10) {
            let line = String(decoding: pending[pending.startIndex..<nl], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            pending = Data(pending[pending.index(after: nl)...])
            if !line.isEmpty { handle(line) }
        }
    }

    /// One line from the script.
    func handle(_ line: String) {
        let (word, rest) = line.firstIndex(of: " ").map { (String(line[..<$0]), String(line[line.index(after: $0)...])) } ?? (line, "")
        switch word {
        case "READY": emit(.ready)
        case "WAKE":
            failures = 0
            emit(.wake)
            // "Hey Mochi, dance" in one breath: the request came with the wake phrase.
            if let request = WakePhrase.command(in: rest, name: name), !request.isEmpty { emit(.heard(request)) }
        case "HEARD":
            let request = WakePhrase.command(in: rest, name: name) ?? rest
            finished = true
            emit(request.isEmpty ? .nothing : .heard(request))
        case "NOTHING":
            finished = true
            emit(.nothing)
        case "NORECOGNIZER":
            finished = true
            stop()
            emit(.failed("Windows has no speech recogniser for your language. Add one in Settings › Time & language › Speech."))
        case "ERROR":
            finished = true
            stop()
            emit(.failed(rest.lowercased().contains("audio") || rest.lowercased().contains("device")
                         ? "I can't hear you: no microphone was found, or Mochi isn't allowed to use it (Settings › Privacy › Microphone)."
                         : "Speech recognition stopped: \(rest.prefix(120))"))
        default: break
        }
    }

    private func exited() {
        process = nil
        var fromFile = false
        if case .file = source { fromFile = true }
        if mode == "once" || fromFile {
            if !finished { finished = true; emit(.nothing) }
            return
        }
        // Wake listening ended by itself (the microphone went away for a moment): start again, a few times.
        failures += 1
        guard failures <= 5 else { emit(.failed("Listening for \u{201C}Hey \(name)\u{201D} keeps stopping, so I've switched it off.")); return }
        let token = session
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(failures * 3)) { [weak self] in
            guard let self, self.session == token else { return }
            self.start("wake", name: self.name, source: self.source)
        }
    }

    private func emit(_ e: VoiceEvent) { onEvent?(e) }

    /// For tests: speak `text` into a WAV file with the Windows voice. Returns whether it worked.
    static func synthesize(_ text: String, to url: URL) -> Bool {
        let script = """
        Add-Type -AssemblyName System.Speech
        $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $s.Rate = -1
        $s.SetOutputToWaveFile('\(quote(url.path))')
        $s.Speak('\(quote(text))')
        $s.Dispose()
        """
        let done = DispatchSemaphore(value: 0)
        let p = HiddenProcess(executable: HiddenProcess.powershell,
                              arguments: ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-EncodedCommand", HiddenProcess.encode(script)])
        p.onExit = { done.signal() }
        guard p.start() else { return false }
        _ = done.wait(timeout: .now() + 60)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Inside single quotes, PowerShell only needs ' doubled.
    private static func quote(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }

    static func script(mode: String, name: String, wave: String) -> String {
        """
        $ErrorActionPreference = 'Stop'
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        function Say($s) { [Console]::Out.WriteLine($s); [Console]::Out.Flush() }
        $mode = '\(quote(mode))'; $name = '\(quote(name))'; $wave = '\(quote(wave))'
        try {
            Add-Type -AssemblyName System.Speech
            $all = [System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers()
            $info = $all | Where-Object { $_.Culture.Name -eq [Globalization.CultureInfo]::CurrentUICulture.Name } | Select-Object -First 1
            if (-not $info) { $info = $all | Where-Object { $_.Culture.TwoLetterISOLanguageName -eq 'en' } | Select-Object -First 1 }
            if (-not $info) { $info = $all | Select-Object -First 1 }
            if (-not $info) { Say 'NORECOGNIZER'; exit 3 }
            $engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine($info)
            if ($wave) { $engine.SetInputToWaveFile($wave) } else { $engine.SetInputToDefaultAudioDevice() }
            $engine.EndSilenceTimeout = [TimeSpan]::FromMilliseconds(900)
            $engine.EndSilenceTimeoutAmbiguous = [TimeSpan]::FromMilliseconds(1300)

            $dictation = New-Object System.Speech.Recognition.DictationGrammar
            $calls = New-Object System.Speech.Recognition.Choices
            foreach ($g in 'hey', 'hi', 'hello', 'okay') { $calls.Add("$g $name") }
            $wakeOnly = New-Object System.Speech.Recognition.Grammar((New-Object System.Speech.Recognition.GrammarBuilder($calls)))
            $wakeOnly.Name = 'wake'
            $withRequest = New-Object System.Speech.Recognition.GrammarBuilder($calls)
            $withRequest.AppendDictation()
            $wakePlus = New-Object System.Speech.Recognition.Grammar($withRequest)
            $wakePlus.Name = 'wakeplus'

            function Request([double]$seconds) {
                $engine.UnloadAllGrammars(); $engine.LoadGrammar($dictation)
                $engine.InitialSilenceTimeout = [TimeSpan]::FromSeconds($seconds)
                $r = $engine.Recognize()
                if ($r -and $r.Text) { Say ('HEARD ' + $r.Text) } else { Say 'NOTHING' }
            }

            if ($mode -eq 'once') { Say 'READY'; Request 8; exit 0 }

            while ($true) {
                $engine.UnloadAllGrammars(); $engine.LoadGrammar($wakeOnly); $engine.LoadGrammar($wakePlus)
                $engine.InitialSilenceTimeout = [TimeSpan]::Zero          # wait as long as it takes
                $r = $engine.Recognize()
                if (-not $r) { if ($wave) { break } else { continue } }
                # The name itself must be heard clearly; a near miss is just someone talking.
                $called = @($r.Words | Select-Object -First 2 | Where-Object { $_.Confidence -lt 0.5 }).Count -eq 0
                if (-not $called -and $r.Confidence -lt 0.6) { continue }
                Say ('WAKE ' + $r.Text)
                if ($r.Grammar.Name -eq 'wake') { Request 7 }
            }
        } catch {
            Say ('ERROR ' + $_.Exception.Message)
            exit 1
        }
        """
    }
}
#endif
