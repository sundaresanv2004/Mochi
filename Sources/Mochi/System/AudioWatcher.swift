#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif
#if canImport(CoreAudio)
import CoreAudio
#endif

/// What kind of sound is playing on the Mac right now.
enum MediaActivity: Equatable {
    case none
    case music      // a song: Spotify, Apple Music, YouTube Music…
    case podcast    // a podcast or an audiobook
    case video      // YouTube and other clips
    case movie      // a film or a show: Netflix, Prime Video, the TV app, IINA…
    case call       // Zoom, Teams, FaceTime, Discord: only inside the watcher, reported as `onCall`
    case other      // an app with the speakers open (only when Now Playing can't be read)

    /// Something with pictures that the pet sits down to watch.
    var isWatching: Bool { self == .video || self == .movie }
}

extension Notification.Name {
    /// Posted by `AudioWatcher` when `current` or `onCall` changes, so the pets react at once.
    static let mochiMediaChanged = Notification.Name("MochiMediaChanged")
}

/// Works out what kind of sound is playing on the Mac. Needs no permission and never hears the audio.
///
/// Music and videos come from the system's Now Playing (`NowPlaying`): the player itself says whether it is
/// playing, so pausing is noticed within a second, and apps that merely hold the speakers open (dictation
/// tools, chat apps, an idle browser tab) don't count. Calls come from Core Audio's process list: a chat app
/// that is using the microphone. If Now Playing can't be read, everything comes from that process list,
/// as before.
final class AudioWatcher {
    /// One watcher for the whole app, however many pets are on screen.
    static let shared = AudioWatcher()
    private var started = false
    /// What is playing (music, a podcast, a video, a film…), whether or not you are also on a call.
    private(set) var current: MediaActivity = .none
    /// A chat app is using the microphone (Zoom, Discord, FaceTime…). Kept apart from `current`, so a
    /// YouTube video watched while sitting in a Discord voice channel is still a video, just a quiet one.
    private(set) var onCall = false
    private var timer: Timer?

    /// Real play/pause state for apps that keep their audio stream open while paused (Spotify, Music),
    /// for when Now Playing can't be read. They announce changes system-wide, which needs no permission.
    private var playing: [String: Bool] = [:]

    private let nowPlaying = NowPlaying.shared

    func start() {
        guard !started else { resume(); return }
        started = true
        #if os(macOS)
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
                           object: nil, queue: .main) { [weak self] n in self?.record("spotify", n) }
        for name in ["com.apple.Music.playerInfo", "com.apple.iTunes.playerInfo"] {
            center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] n in
                self?.record("music", n)
            }
        }
        #endif
        nowPlaying.onChange = { [weak self] in self?.poll() }
        nowPlaying.start()
        schedule()
    }

    /// Stop watching while the Mac sleeps or the screen is locked.
    func pause() {
        timer?.invalidate()
        timer = nil
        nowPlaying.stop()
    }

    func resume() {
        guard started, timer == nil else { return }
        nowPlaying.start()
        schedule()
    }

    private func schedule() {
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func record(_ app: String, _ note: Notification) {
        let state = (note.userInfo?["Player State"] as? String)?.lowercased()
        playing[app] = (state == "playing")
    }

    /// What was found at the last look, for the Debug page: each source of sound and how it was read.
    private(set) var sources: [String] = []

    // MARK: Settling

    /// A change has to hold for a moment before it counts, so a notification ding or the gap between two
    /// songs doesn't flip the pet's mood. Now Playing is exact, so its changes need only a moment; sound
    /// seen in the process list can be a ding or a stream left open, so it needs a few seconds.
    struct Settle {
        private(set) var value: MediaActivity
        private var candidate: MediaActivity
        private var since = Date.distantPast

        init(_ value: MediaActivity = .none) { self.value = value; candidate = value }

        /// Feed what is heard now; returns how long to wait before looking again (nil: settled).
        mutating func feed(_ heard: MediaActivity, exact: Bool, now: Date = Date()) -> TimeInterval? {
            if heard != candidate { candidate = heard; since = now }
            guard candidate != value else { return nil }
            let needed = AudioWatcher.delay(from: value, to: candidate, exact: exact)
            let waited = now.timeIntervalSince(since)
            if waited >= needed { value = candidate; return nil }
            return needed - waited
        }
    }

    /// How long a change must hold. Starting is quick (the music is already playing); stopping waits a
    /// little longer, so the pause between two songs doesn't end the vibe.
    static func delay(from old: MediaActivity, to new: MediaActivity, exact: Bool) -> TimeInterval {
        guard exact, old != .call, new != .call else { return new == .none ? 4 : 3 }
        return new == .none ? 0.6 : 0.3
    }

    private var settleCurrent = Settle()
    private var settleCall = Settle()
    private var recheck: DispatchWorkItem?
    private var lastFound = Set<MediaActivity>()

    /// Looks again (`fresh`), or only re-checks a change that is waiting to settle.
    private func poll(fresh: Bool = true) {
        if fresh { lastFound = detect() }
        let exact = nowPlaying.state != nil
        let before = (current, onCall)
        let wait1 = settleCurrent.feed(Self.loudest(lastFound), exact: exact)
        // Calls are only ever seen in the process list, so they always take a few seconds to settle.
        let wait2 = settleCall.feed(lastFound.contains(.call) ? .call : .none, exact: false)
        current = settleCurrent.value
        onCall = settleCall.value == .call
        if let wait = [wait1, wait2].compactMap({ $0 }).min() {
            recheck?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.poll(fresh: false) }
            recheck = work
            DispatchQueue.main.asyncAfter(deadline: .now() + wait + 0.02, execute: work)
        }
        if before != (current, onCall) { NotificationCenter.default.post(name: .mochiMediaChanged, object: self) }
    }

    /// What's playing, if several things are: music, then talk, then pictures, then an app that merely has
    /// the speakers open. (A call isn't something playing: see `onCall`.)
    private static func loudest(_ found: Set<MediaActivity>) -> MediaActivity {
        for kind in [MediaActivity.music, .podcast, .movie, .video, .other] where found.contains(kind) { return kind }
        return .none
    }

    // MARK: Detecting

    /// What a Now Playing report counts as: nothing unless it is playing (see `MediaClassifier`).
    func kind(of np: NowPlaying.State) -> MediaActivity? {
        guard np.playing else { return nil }
        switch np.kind {
        case .music: return .music
        case .podcast: return .podcast
        case .movie: return .movie
        case .video: return .video
        }
    }

    /// Something is playing in a private browser window (see `MediaClassifier.isPrivate`).
    var playingPrivately: Bool { playingNow?.isPrivate ?? false }

    /// The Now Playing item behind `current`, while something is playing: the app, title and artist.
    var playingNow: NowPlaying.State? {
        guard let np = nowPlaying.state, np.playing, current != .none, current != .other else { return nil }
        return np
    }

    private func detect() -> Set<MediaActivity> {
        var found = Set<MediaActivity>()
        var seen: [String] = []
        let np = nowPlaying.state
        if let np {
            let who = np.name ?? np.app ?? "Something"
            if let kind = kind(of: np) {
                found.insert(kind)
                // Private windows: never the title, just that it's private.
                let what = np.isPrivate ? ", in a private window" : (np.title.map { ", " + $0 } ?? "")
                seen.append("Now Playing: \(who) (\(Self.name(kind).lowercased()))\(what)")
            } else {
                seen.append(np.app == nil ? "Now Playing: nothing" : "Now Playing: \(who), paused")
            }
        }
        if #available(macOS 14.2, *) {
            for p in audioProcesses() where p.output {
                guard var kind = classify(p.bundleID, nowPlaying: np != nil) else {
                    if np == nil, isPausable(p.bundleID) { seen.append("\(p.bundleID): open but not playing") }
                    continue
                }
                // A chat app only counts as a call while it is also using the microphone;
                // otherwise it is just an app that happens to be making (or holding) sound.
                if kind == .call, !p.input { kind = .other }
                // With Now Playing known, the process list only decides calls: an app that just has the
                // speakers open may be silent (dictation, an idle tab, a chat app between dings).
                if let np, kind != .call {
                    // The Now Playing app itself (or its helper, e.g. com.google.Chrome.helper) is already listed.
                    let isPlayer = np.app.map { p.bundleID == $0 || p.bundleID.hasPrefix($0 + ".") } ?? false
                    if !isPlayer { seen.append("\(p.bundleID): has the speakers open, not counted (not in Now Playing)") }
                    continue
                }
                found.insert(kind)
                seen.append("\(p.bundleID): \(Self.name(kind))")
            }
        } else if np == nil, defaultOutputRunning() {
            found.insert(.other)
            seen.append("Something is using the speakers")
        }
        sources = seen
        return found
    }

    static func name(_ kind: MediaActivity) -> String {
        switch kind {
        case .none: return "Nothing"
        case .music: return "Music"
        case .podcast: return "Podcast"
        case .video: return "Video"
        case .movie: return "Movie or show"
        case .call: return "Call"
        case .other: return "Other sound"
        }
    }

    private func isPausable(_ bundleID: String) -> Bool {
        let b = bundleID.lowercased()
        return b.contains("spotify") || b.contains("com.apple.music") || b.contains("com.apple.itunes")
    }

    // MARK: Classification

    /// `nowPlaying`: the play state comes from Now Playing, so music players needn't be checked here.
    private func classify(_ bundleID: String, nowPlaying: Bool = false) -> MediaActivity? {
        let b = bundleID.lowercased()
        func has(_ keys: [String]) -> Bool { keys.contains { b.contains($0) } }

        // system sounds and helpers we should ignore
        if has(["com.apple.audio", "com.apple.coreaudio", "com.apple.systemsound", "com.apple.accessibility",
                "com.apple.siri", "corespeech", "com.apple.notificationcenter", "com.apple.speech", "com.apple.voiceover",
                "com.apple.controlcenter", "mochi", "audiodg", "shellexperiencehost", "systemsounds"]) { return nil }

        // Spotify and Apple Music hold their audio stream open even when paused, so only count them
        // while they say they are actually playing. (Before the first play/pause/track change since
        // Mochi started, their state is unknown and they are ignored.)
        if has(["spotify"]) { return nowPlaying || playing["spotify"] == true ? .music : nil }
        if has(["com.apple.music", "com.apple.itunes"]) { return nowPlaying || playing["music"] == true ? .music : nil }

        if has(["us.zoom", "com.microsoft.teams", "com.apple.facetime", "slack", "skype", "webex", "discord",
                "com.apple.ichat", "whatsapp", "com.hnc", "zoom", "ms-teams", "msteams", "teams.exe"]) { return .call }
        if has(["tidal", "amazon.music", "garageband", "ableton", "deezer", "soundcloud", "pandora", "vox",
                "swinsian"]) { return .music }
        if has(["quicktime", "videolan", "vlc.exe", "iina", "com.apple.tv", "plex", "mpv", "netflix", "infuse", "disney"]) { return .video }
        return .other           // browsers and anything else that makes sound
    }

    // MARK: Core Audio

    struct AudioProcess {
        let bundleID: String
        let output: Bool        // sending sound to the speakers
        let input: Bool         // listening to the microphone
    }

#if os(macOS)
    @available(macOS 14.2, *)
    private func audioProcesses() -> [AudioProcess] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }

        func flag(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Bool {
            var value: UInt32 = 0
            var vsize = UInt32(MemoryLayout<UInt32>.size)
            var vaddr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                   mElement: kAudioObjectPropertyElementMain)
            return AudioObjectGetPropertyData(id, &vaddr, 0, nil, &vsize, &value) == noErr && value != 0
        }

        let me = ProcessInfo.processInfo.processIdentifier
        var result: [AudioProcess] = []
        for id in ids {
            let output = flag(id, kAudioProcessPropertyIsRunningOutput)
            let input = flag(id, kAudioProcessPropertyIsRunningInput)
            guard output || input else { continue }

            var pid: pid_t = 0
            var psize = UInt32(MemoryLayout<pid_t>.size)
            var paddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID,
                                                   mScope: kAudioObjectPropertyScopeGlobal,
                                                   mElement: kAudioObjectPropertyElementMain)
            if AudioObjectGetPropertyData(id, &paddr, 0, nil, &psize, &pid) == noErr, pid == me { continue }

            var name: Unmanaged<CFString>?
            var nsize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var naddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID,
                                                   mScope: kAudioObjectPropertyScopeGlobal,
                                                   mElement: kAudioObjectPropertyElementMain)
            var bundle = "unknown"
            if AudioObjectGetPropertyData(id, &naddr, 0, nil, &nsize, &name) == noErr, let s = name?.takeRetainedValue() {
                bundle = s as String
            }
            result.append(AudioProcess(bundleID: bundle, output: output, input: input))
        }
        return result
    }

    /// Fallback for older macOS: is anything using the default output device?
    private func defaultOutputRunning() -> Bool {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &device) == noErr else { return false }
        var running: UInt32 = 0
        var rsize = UInt32(MemoryLayout<UInt32>.size)
        var raddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                               mScope: kAudioObjectPropertyScopeGlobal,
                                               mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(device, &raddr, 0, nil, &rsize, &running) == noErr && running != 0
    }
#endif
}
