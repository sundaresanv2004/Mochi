#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Reacting to what is playing on the Mac. `AudioWatcher` says what kind of thing it is (music, a podcast,
/// a video, a film or a show, a call) and `NowPlaying` what exactly; this decides how the pet takes it:
///
/// - music: vibing along while it goes about its day, and an act: DJ, air guitar, karaoke, rave, bongos
/// - podcast: calm, the odd "mm-hmm", and an act: earbud, notes, coffee, radio, deep thinking
/// - video: watching in the screen's glow, giggling, and an act: phone, snacks, like, subscribe, comments
/// - film or show: quiet and still until it ends, and an act: 3D cinema, blanket, soda, scary, tearjerker
/// Each pet picks its own act (`MediaAct`) and switches every few minutes, so it never gets old.
/// In a private window (the browser hides what's playing) it looks away instead, in a way that fits the
/// browser, and never says, notes or tells the model anything about it.
/// A call is separate (`onCall`): the pet keeps quiet, but still watches or listens along with you.
extension PetController {
    /// What's playing, as far as the settings let the pet care. Runs every second, and straight away
    /// whenever the audio watcher notices a change.
    func refreshMedia() {
        var m = settings.reactToMedia ? audio.current : .none
        // "Other" just means some app has the speakers open, which is often silence: opt-in only.
        if m == .other, !settings.reactToOtherAudio { m = .none }
        let call = settings.quietOnCalls && audio.onCall
        if call != onCall {
            onCall = call
            callChanged()
        }
        let secret = m != .none && audio.playingPrivately
        if m != media || secret != privately {
            let before = media
            media = m
            privately = secret
            mediaChanged(from: before)
        } else if settings.reactToMedia {
            noticeNewTrack()
        }
        updateBeat()
    }

    func mediaChanged(from before: MediaActivity = .none) {
        let np = audio.playingNow
        playingTitle = np?.title
        nextMediaMoment = Date().addingTimeInterval(.random(in: 40...90))
        if privately {
            // Private: no remark about it (not even from the model), nothing for the diary. Just look away.
            updateBeat()
            if isMain { say(Dialogue.privateStart.randomElement()!) }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 4)) }
            return
        }
        switch media {
        case .music, .other:
            if !isMain {}
            else if media == .music {
                let fallback = np?.title.flatMap { $0.count <= 32 ? Dialogue.songStart($0).randomElement() : nil }
                react("Music just started playing\(describe(np))", fallback: fallback ?? Dialogue.musicStart.randomElement()!, note: true)
            }
            else if Bool.random() { say("Something's playing… 🎧") }
            // No stopping to dance: the headphones go on and it carries on with whatever it was doing,
            // grooving to the beat (see PetView.vibing). Standing about, it gives a happy little bounce first.
            if canAct, !userAway, action == .idle || action == .lookAround { apply(Decision(action: .happy, duration: 1.6)) }
        case .podcast:
            if isMain { react("Your human started listening to \(np?.app?.contains("audible") == true || np?.app?.contains("books") == true ? "an audiobook" : "a podcast")\(describe(np))",
                              fallback: Dialogue.podcastStart.randomElement()!, note: true) }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 4)) }
        case .video:
            if isMain {
                let fallback = np?.artist.flatMap { $0.count <= 24 ? Dialogue.videoNamed($0).randomElement() : nil }
                react("Your human started watching a video\(describe(np))", fallback: fallback ?? Dialogue.videoStart.randomElement()!, note: true)
            }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 5)) }
        case .movie:
            // The one thing it says before going quiet for the film (force: films silence the pet).
            if isMain { react("Your human started watching a film or show\(describe(np)); you're watching too\(view.act.map { ", " + $0.doing } ?? "")",
                              fallback: Dialogue.movieStart.randomElement()!, force: true, note: true) }
            if canAct, !userAway { apply(Decision(action: .idle, duration: 6)) }
        case .call:
            break                                   // never set: calls are `onCall`
        case .none:
            if isMain, before == .movie { react("The film or show you were watching together just ended", fallback: Dialogue.movieEnd.randomElement()!) }
        }
        updateBeat()
    }

    /// A call started or ended. The pet goes quiet, and stops whatever it was doing to listen; anything
    /// playing carries on as before (gear, vibing), just silently.
    func callChanged() {
        guard onCall else { return }
        if isMain { say("Shh… I'll be quiet 🤫", force: true) }
        if canAct, !userAway, !media.isWatching { apply(Decision(action: .idle, duration: 5)) }
    }

    /// " (“Song” by Artist in Spotify)": what the model is told about the item, when known.
    func describe(_ np: NowPlaying.State?) -> String {
        guard let np else { return soundSource }
        var parts: [String] = []
        if let t = np.title { parts.append("\u{201C}\(t.prefix(80))\u{201D}") }
        if let a = np.artist { parts.append("by \(a.prefix(40))") }
        if let n = np.name { parts.append("in \(n)") }
        return parts.isEmpty ? "" : ": " + parts.joined(separator: " ")
    }

    /// A new song (or episode) while the same kind of thing keeps playing: now and then it notices.
    func noticeNewTrack() {
        guard isMain, !privately, media == .music || media == .podcast, let np = audio.playingNow, let title = np.title,
              title != playingTitle else { return }
        let first = playingTitle == nil
        playingTitle = title
        guard !first else { return }
        // A new song is a good moment for a new act.
        if media == .music, Double.random(in: 0..<1) < 0.4 { switchAct(announce: false) }
        guard media == .music, Double.random(in: 0..<1) < 0.3 else { return }
        react("The next song just started\(describe(np))", fallback: Dialogue.newSong.randomElement()!)
    }

    /// Little reactions while a podcast or a video plays: a nod and a word, a giggle. Once a second.
    func mediaTick(_ now: Date) {
        if now >= nextActChange, view.act != nil { switchAct(announce: true) }
        guard now >= nextMediaMoment else { return }
        nextMediaMoment = now.addingTimeInterval(.random(in: 45...120))
        guard isMain || Bool.random(), canAct, !userAway, action == .idle || action == .lookAround || { if case .walk = action { return true }; return false }() else { return }
        switch media {
        case .podcast:
            if Bool.random() { say(Dialogue.podcastListening.randomElement()!) }
            apply(Decision(action: .lookAround, duration: 2.5))
        case .video:
            apply(Decision(action: .happy, duration: 1.2))
            if Double.random(in: 0..<1) < 0.6 { say(Dialogue.videoGiggle.randomElement()!) }
        default:
            break
        }
    }

    /// Whether the pet should be vibing: headphones on and grooving to the beat. During a call too
    /// (say, a Discord voice channel with Spotify playing): the vibe is only visual, and the pet stays quiet.
    var hearsMusic: Bool { media == .music || media == .other }

    /// Picks another act for what's playing (or none when nothing is), and says something about it now and then.
    func switchAct(announce: Bool) {
        let next: MediaAct?
        if privately {
            // The browser's own act first (Chrome's incognito spy, Firefox's mask…), then any of the others.
            let browser = MediaClassifier.Browser(app: audio.playingNow?.app)
            next = view.act?.isPrivacy == true ? MediaAct.pickPrivate(after: view.act) : MediaAct.signature(for: browser)
        } else {
            next = MediaAct.pick(for: media, after: view.act)
        }
        view.act = next
        nextActChange = next == nil ? .distantFuture : Date().addingTimeInterval(.random(in: 120...200))
        guard announce, let next, Double.random(in: 0..<1) < 0.5 else { return }
        say(Dialogue.actStart(next).randomElement()!)
    }

    /// Puts the right act on for what's playing (music, podcast, video or film), and the beat for music.
    func updateBeat() {
        let wanted: MediaActivity? = [.music, .podcast, .video, .movie].contains(media) ? media : nil
        if privately {
            if view.act?.isPrivacy != true { switchAct(announce: false) }
        } else if view.act?.kind != wanted || view.act?.isPrivacy == true {
            switchAct(announce: false)
        }

        let on = hearsMusic
        guard on != (view.musicBpm > 0) else { return }
        if on {
            view.musicBpm = .random(in: 100...126)
        } else {
            view.musicBpm = 0
            // A dance that started to the music ends with it, instead of playing out its last few seconds.
            if action == .dance, social == .none { remaining = min(remaining, 0.4) }
            if isMain, media == .none { react("The music you were vibing to just stopped", fallback: Dialogue.musicStopped.randomElement()!) }
        }
    }
}
