import Foundation

/// What the system's Now Playing says is playing: the same source as the media controls in Control Center.
///
/// Every app that plays media properly reports here (Spotify, Music, YouTube or any site in a browser,
/// podcast apps, video players), together with whether it is actually playing. Apps that merely hold the
/// speakers open (dictation tools, chat apps, an idle browser tab) never do, so this is far more accurate
/// than watching which apps use the speakers.
///
/// Since macOS 15.4 the MediaRemote framework behind it only answers Apple's own programs, so a tiny
/// script runs in `osascript` (an Apple program) and reports changes, one JSON line each. It never sees
/// the audio, only the player's name, the title and whether it is playing. No permission is needed.
final class NowPlaying {
    static let shared = NowPlaying()

    struct State: Equatable {
        var playing: Bool
        var app: String?        // bundle identifier of the player ("com.spotify.client", "com.google.Chrome")
        var name: String?       // its name as the system shows it ("Spotify")
        var title: String?
        var artist: String?     // artist, podcast or YouTube channel
        var album: String?
        var duration: Double?   // seconds, when the player says
        var video: Bool         // the player says it is showing a video
        var audio: Bool         // the player says it is playing audio only

        init(playing: Bool, app: String?, name: String? = nil, title: String? = nil, artist: String? = nil,
             album: String? = nil, duration: Double? = nil, video: Bool = false, audio: Bool = false) {
            self.playing = playing; self.app = app; self.name = name; self.title = title; self.artist = artist
            self.album = album; self.duration = duration; self.video = video; self.audio = audio
        }

        /// What kind of thing this is: a song, a podcast, a film, a YouTube video…
        var kind: MediaClassifier.Kind { MediaClassifier.kind(of: self) }

        /// Playing in a private (incognito) window: the browser hides what it is.
        var isPrivate: Bool { MediaClassifier.isPrivate(app: app, title: title, artist: artist) }
    }

    /// The latest report, or nil while it isn't known (not started, or the helper can't run on this Mac).
    private(set) var state: State?
    /// Called on the main thread whenever `state` changes.
    var onChange: (() -> Void)?

    #if os(Windows)
    private var process: HiddenProcess?
    #else
    private var process: Process?
    #endif
    private var buffer = Data()
    private var wanted = false
    private var failures = 0

    /// How often the helper looks. Twice a second keeps it cheap (about 0.3% of one core) while a pause
    /// still reaches the pet within half a second.
    static let interval = 0.5

    func start() {
        wanted = true
        guard process == nil else { return }
        launch()
    }

    func stop() {
        wanted = false
        process?.terminate()
        process = nil
        if state != nil { state = nil; onChange?() }
    }

    #if os(Windows)
    /// Windows: a PowerShell helper reads the system media controls (the same source as the media flyout)
    /// and reports changes in the same JSON lines as the macOS helper. No console window, no permission.
    private func launch() {
        let p = HiddenProcess(executable: HiddenProcess.powershell,
                              arguments: ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                                          "-EncodedCommand", HiddenProcess.encode(Self.windowsScript)])
        p.onOutput = { [weak self] data in DispatchQueue.main.async { self?.received(data) } }
        p.onExit = { [weak self, weak p] in DispatchQueue.main.async { self?.ended(p) } }
        if p.start() { process = p } else { process = nil; ended(nil) }
    }
    #else
    private func launch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-l", "JavaScript", "-e", Self.script]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty else { h.readabilityHandler = nil; return }
            DispatchQueue.main.async { self?.received(data) }
        }
        p.terminationHandler = { [weak self] ended in
            DispatchQueue.main.async { self?.ended(ended) }
        }
        do {
            try p.run()
            process = p
        } catch {
            process = nil
            ended(nil)
        }
    }
    #endif

    /// The helper stopped. Unless Mochi asked it to, start it again, backing off if it keeps failing:
    /// meanwhile `state` is nil and the audio watcher falls back to watching the speakers.
    #if os(Windows)
    private func ended(_ p: HiddenProcess?) { stopped(p === process || p == nil) }
    #else
    private func ended(_ p: Process?) { stopped(p == nil || p === process) }
    #endif

    private func stopped(_ current: Bool) {
        guard current else { return }
        process = nil
        buffer.removeAll()
        if state != nil { state = nil; onChange?() }
        guard wanted else { return }
        failures += 1
        guard failures <= 5 else { return }                        // it can't run here: stay on the fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(failures * 3)) { [weak self] in
            guard let self, self.wanted, self.process == nil else { return }
            self.launch()
        }
    }

    private func received(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            // The framework isn't there or misbehaved: say "unknown" so the speakers are watched instead.
            let next: State? = obj["error"] == nil ? Self.state(from: obj) : nil
            if next != nil { failures = 0 }
            if next != state { state = next; onChange?() }
        }
    }

    /// One report from the helper.
    static func state(from obj: [String: Any]) -> State {
        func text(_ key: String) -> String? {
            guard let s = obj[key] as? String, !s.isEmpty else { return nil }
            return s
        }
        let length = (obj["duration"] as? NSNumber)?.doubleValue
        return State(playing: obj["playing"] as? Bool ?? false, app: text("app"), name: text("name"),
                     title: text("title"), artist: text("artist"), album: text("album"),
                     duration: length.flatMap { $0 > 0 && $0.isFinite ? $0 : nil },
                     video: (obj["type"] as? Int) == 2, audio: (obj["type"] as? Int) == 1)
    }

    /// Runs inside osascript. Reads Now Playing every `interval` seconds, prints a line when anything
    /// changes, and quits as soon as Mochi does (its parent process changes).
    private static let script = """
    ObjC.import('Foundation');
    ObjC.bindFunction('getppid', ['int', []]);
    $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/').load;
    const R = $.NSClassFromString('MRNowPlayingRequest');
    const out = $.NSFileHandle.fileHandleWithStandardOutput;
    const parent = $.getppid();
    function str(v) { return (v === undefined || v === null || v.isNil()) ? null : ObjC.unwrap(v); }
    function read() {
      if (R.isNil()) return {error: 'unavailable'};
      const client = R.localNowPlayingPlayerPath.client;
      const item = R.localNowPlayingItem;
      const md = item.isNil() ? null : item.metadata;
      return {
        playing: !!R.localIsPlaying,
        app: client.isNil() ? null : str(client.bundleIdentifier),
        name: client.isNil() ? null : str(client.displayName),
        title: md === null || md.isNil() ? null : str(md.title),
        artist: md === null || md.isNil() ? null : str(md.trackArtistName),
        album: md === null || md.isNil() ? null : str(md.albumName),
        duration: md === null || md.isNil() ? 0 : Math.round(Number(md.duration) || 0),
        type: md === null || md.isNil() ? 0 : Number(md.mediaType)
      };
    }
    let last = '';
    while ($.getppid() === parent) {
      let line;
      try { line = JSON.stringify(read()); } catch (e) { line = JSON.stringify({error: String(e)}); }
      if (line !== last) {
        out.writeData($(line + '\\n').dataUsingEncoding($.NSUTF8StringEncoding));
        last = line;
      }
      $.NSThread.sleepForTimeInterval(\(interval));
    }
    """

    #if os(Windows)
    /// Runs in PowerShell. Reads the media session every `interval` seconds (preferring one that is playing),
    /// prints a line when anything changes, and quits as soon as Mochi does.
    private static var windowsScript: String { """
    $ErrorActionPreference = 'Stop'
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $parent = \(ProcessInfo.processInfo.processIdentifier)
    function Say($o) { [Console]::Out.WriteLine(($o | ConvertTo-Json -Compress)); [Console]::Out.Flush() }
    try {
      Add-Type -AssemblyName System.Runtime.WindowsRuntime
      $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
      function Await($op, [Type]$t) { $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op)); [void]$task.Wait(-1); $task.Result }
      $M = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
      $P = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime]
      $mgr = Await ($M::RequestAsync()) $M
    } catch { Say @{ error = "$_" }; exit 1 }
    $names = @{ 'chrome' = 'Google Chrome'; 'msedge' = 'Microsoft Edge'; '308046b0af4a39cb' = 'Firefox'; 'brave' = 'Brave';
                'spotify.exe' = 'Spotify'; 'spotify' = 'Spotify'; 'opera' = 'Opera'; 'vivaldi' = 'Vivaldi' }
    $last = ''
    while ($true) {
      if (-not (Get-Process -Id $parent -ErrorAction SilentlyContinue)) { break }
      try {
        $s = $null
        foreach ($x in $mgr.GetSessions()) { if ($x.GetPlaybackInfo().PlaybackStatus.ToString() -eq 'Playing') { $s = $x; break } }
        if ($null -eq $s) { $s = $mgr.GetCurrentSession() }
        if ($null -eq $s) { $o = [ordered]@{ playing = $false; app = $null } }
        else {
          $info = $s.GetPlaybackInfo()
          $props = Await ($s.TryGetMediaPropertiesAsync()) $P
          $tl = $s.GetTimelineProperties()
          $type = 0
          if ($null -ne $info.PlaybackType) { switch ($info.PlaybackType.ToString()) { 'Music' { $type = 1 } 'Video' { $type = 2 } } }
          $app = $s.SourceAppUserModelId
          $key = $app.ToLower()
          $name = $names[$key]
          if (-not $name) { $name = ($app -split '!')[-1] -replace '\\.exe$', '' -replace '^.*\\.', '' }
          $o = [ordered]@{ playing = ($info.PlaybackStatus.ToString() -eq 'Playing'); app = $key; name = $name;
                           title = $props.Title; artist = $props.Artist; album = $props.AlbumTitle;
                           duration = [math]::Round(($tl.EndTime - $tl.StartTime).TotalSeconds); type = $type }
        }
        $line = $o | ConvertTo-Json -Compress
      } catch { $line = (@{ error = "$_" } | ConvertTo-Json -Compress) }
      if ($line -ne $last) { [Console]::Out.WriteLine($line); [Console]::Out.Flush(); $last = $line }
      Start-Sleep -Milliseconds \(Int(interval * 1000))
    }
    """ }
    #endif
}
