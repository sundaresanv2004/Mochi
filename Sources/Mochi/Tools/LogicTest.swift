#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Developer helper: `Mochi --logic-test` runs the reminder clocks and twenty simulated minutes of
/// ordinary pet life without waiting, and prints PASS / FAIL lines.
enum LogicTest {
    static func run() {
        _ = NSApplication.shared
        PetAI.shared.suspended = true              // a simulated day must never call a real model
        var failures = 0
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if !ok { failures += 1 }
            print("\(ok ? "PASS" : "FAIL")  \(name)\(detail.isEmpty ? "" : "  [\(detail)]")")
        }

        let s = PetSettings.shared
        let saved = (s.reminderMinutes, s.secondPet)
        defer { s.reminderMinutes = saved.0; s.secondPet = saved.1 }

        // MARK: Reminders
        print("--- Reminders ---")
        check("10 minutes is offered", ReminderKind.intervals.contains(10))
        s.reminderMinutes = [ReminderKind.water.rawValue: 10]
        let a = PetController()
        a.lastSlow = .distantFuture                // keep the once-a-second real-time checks out of the simulation
        var clock = Date()
        func pass(_ seconds: Int, idle: TimeInterval) {
            for _ in 0..<seconds { clock += 1; a.checkReminders(1, idle: idle, clock) }
        }
        a.reminderElapsed = [:]; a.lastReminder = .distantPast
        var said = a.saidCount
        pass(598, idle: 2)
        check("nothing before the interval is up", a.saidCount == said)
        pass(3, idle: 2)
        check("water reminder fires at 10 minutes", a.saidCount == said + 1 && Dialogue.reminder(.water).contains(a.lastSaid), a.lastSaid)
        check("its clock restarts", (a.reminderElapsed[.water] ?? 99) < 5)

        pass(300, idle: 100)
        check("keeps counting while you read (no input for under 5 min)", (a.reminderElapsed[.water] ?? 0) >= 299)
        let before = a.reminderElapsed[.water] ?? 0
        pass(200, idle: 400)
        check("pauses once you've been away 5 minutes", a.reminderElapsed[.water] == before)
        pass(5, idle: 1000)
        check("starts over after a 15 minute break", a.reminderElapsed[.water] == nil)

        said = a.saidCount
        a.onCall = true
        pass(700, idle: 2)
        check("held back during a call", a.saidCount == said && (a.reminderElapsed[.water] ?? 0) >= 600)
        a.onCall = false
        pass(2, idle: 2)
        check("fires as soon as the call ends", a.saidCount == said + 1)
        a.reminderElapsed = [:]; a.onCall = true; said = a.saidCount
        pass(905, idle: 2)
        check("a call only delays it by 5 minutes", a.saidCount == said + 1)
        a.onCall = false

        s.reminderMinutes = [ReminderKind.water.rawValue: 10, ReminderKind.posture.rawValue: 10, ReminderKind.eyes.rawValue: 10]
        a.reminderElapsed = [:]
        var shown: [String] = []
        for _ in 0..<700 {
            let n = a.saidCount
            pass(1, idle: 2)
            if a.saidCount != n { shown.append(a.lastSaid) }
        }
        let all = ReminderKind.allCases.flatMap { Dialogue.reminder($0) }
        check("three reminders due together all arrive, one at a time", shown.count == 3 && shown.allSatisfy(all.contains), "\(shown.count) shown")

        var intact = true
        for _ in 0..<40 {                          // the pet's own "*yaaawn*" must never replace the reminder text
            a.debug(.reminder(.posture)); intact = intact && Dialogue.reminder(.posture).contains(a.lastSaid)
            a.debug(.stretch); intact = intact && a.lastSaid.contains("stretch")
        }
        check("posture and stretch reminders are never overwritten by another bubble", intact)
        said = a.saidCount
        for kind in ReminderKind.allCases { a.debug(.reminder(kind)) }
        a.debug(.stretch); a.debug(.calendar); a.debug(.checkIn)
        check("every Debug test button shows a bubble", a.saidCount >= said + 6)

        // MARK: A day in the life
        print("--- 20 simulated minutes alone (\(a.species.name)) ---")
        a.reminderElapsed = [:]
        s.reminderMinutes = [:]
        a.apply(Decision(action: .idle, duration: 1))
        var seconds: [String: Double] = [:]
        var still = 0.0, longestStill = 0.0, moving = 0.0, tilted = 0.0, offscreen = 0
        var last = CGPoint(x: a.cx, y: a.cy)
        said = a.saidCount
        let dt = 1.0 / 30
        for _ in 0..<(20 * 60 * 30) {
            a.tick(CGFloat(dt))
            let name = String(describing: a.action).components(separatedBy: "(")[0]
            seconds[name, default: 0] += dt
            if hypot(a.cx - last.x, a.cy - last.y) > 0.05 { moving += dt; still = 0 } else { still += dt; longestStill = max(longestStill, still) }
            last = CGPoint(x: a.cx, y: a.cy)
            if a.surface != .floor, abs(a.view.spin) > 0.2, a.slipTimer <= 0, !a.thrown { tilted += dt }
            if a.jump == nil, !a.isOnScreen() { offscreen += 1 }     // mid-leap between displays doesn't count
        }
        let summary = seconds.sorted { $0.value > $1.value }.map { "\($0.key) \(Int($0.value))s" }.joined(separator: ", ")
        print("time per action: \(summary)")
        print(String(format: "moving %.0f%% of the time, longest time in one spot %.0fs, said %d things unprompted", moving / 12, longestStill, a.saidCount - said))
        check("never frozen for more than 95 seconds", longestStill <= 95, String(format: "%.0fs", longestStill))
        check("moves at least a quarter of the time", moving / 1200 > 0.25)
        check("never spins or flips while on a wall or the ceiling", tilted < 0.1, String(format: "%.1fs", tilted))
        check("never leaves the screen", offscreen == 0)
        check("ends upright", abs(a.view.spin) < 0.01 || a.action == .spin || a.action == .flip || a.action == .dizzy)

        // MARK: Music
        print("--- Music: moving as usual while vibing ---")
        let brain = MindBrain()
        let ctx = PetContext(surface: .floor, axisFraction: 0.5, cursorDistance: 900, secondsSinceInteraction: 60, hour: 14,
                             platformAbove: false, canClimb: true, canHide: false, media: .music, userAway: false, focusing: false,
                             species: a.species, energy: 0.7, fullness: 0.7, joy: 0.6, bondLevel: 1)
        var picks: [String: Int] = [:]
        for _ in 0..<2000 { picks[String(describing: brain.nextDecision(ctx).action).components(separatedBy: "(")[0], default: 0] += 1 }
        let danceShare = Double(picks["dance"] ?? 0) / 2000
        print("with music on: " + picks.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
        check("with music on it mostly carries on as usual (dances under 30% of the time)", danceShare < 0.3, String(format: "%.0f%% dance", danceShare * 100))
        check("with music on it still walks about the most", picks["walk", default: 0] == picks.values.max())
        check("with music on it still breaks into a dance now and then", danceShare > 0.05, String(format: "%.0f%% dance", danceShare * 100))

        a.apply(Decision(action: .walk(axis: 1), duration: 5))
        a.media = .music
        a.mediaChanged()
        check("music starting doesn't interrupt a walk with a dance", { if case .walk = a.action { return true }; return false }(), "\(a.action)")
        a.view.mood = .walk
        check("walking with music on counts as vibing", a.view.vibing && a.view.musicBpm > 0)
        a.media = .none
        a.mediaChanged()
        check("music stopping ends the vibe", !a.view.vibing && a.view.musicBpm == 0)

        // Spotify playing while a Discord voice channel holds the mic: still music, just a quiet pet.
        a.onCall = true
        a.media = .music
        a.mediaChanged()
        a.view.mood = .idle
        check("music during a call (e.g. a Discord voice channel) still gets the vibe", a.view.vibing && a.view.musicBpm > 0)
        check("…while the pet stays quiet for the call", !a.canSpeak(force: false))
        a.media = .none
        a.mediaChanged()
        check("the vibe ends when that music stops", a.view.musicBpm == 0)
        // The bug: a YouTube video with Discord holding the mic showed nothing, because the call hid the video.
        a.media = .video
        a.mediaChanged()
        check("a video during a call is still watched (screen glow on)", a.view.watching == .video)
        a.media = .movie
        a.mediaChanged()
        check("a film during a call still gets the 3D glasses", a.view.watching == .movie)
        let callFilm = PetContext(surface: .floor, axisFraction: 0.5, cursorDistance: 900, secondsSinceInteraction: 60, hour: 20,
                                  platformAbove: false, canClimb: false, canHide: false, media: .movie, onCall: true, userAway: false,
                                  focusing: false, species: a.species, energy: 0.8, fullness: 0.8, joy: 0.8, bondLevel: 3)
        var watchingOnCall = 0
        for _ in 0..<500 { if case .idle = brain.nextDecision(callFilm).action { watchingOnCall += 1 } }
        check("…and it sits still watching rather than pottering about", watchingOnCall > 400, "\(watchingOnCall / 5)% idle")
        a.onCall = false
        a.media = .none
        a.mediaChanged()

        // MARK: Now Playing
        print("--- Now Playing ---")
        let w = AudioWatcher.shared
        func np(_ playing: Bool, _ app: String?, video: Bool = false) -> NowPlaying.State {
            NowPlaying.State(playing: playing, app: app, video: video)
        }
        check("Spotify playing is music", w.kind(of: NowPlaying.State(playing: true, app: "com.spotify.client", album: "Reprise", duration: 240)) == .music)
        check("Spotify paused is nothing", w.kind(of: np(false, "com.spotify.client")) == nil)
        check("a player that says it shows a video is a video", w.kind(of: np(true, "com.google.Chrome", video: true)) == .video)
        check("IINA playing is a film", w.kind(of: np(true, "com.colliderli.iina")) == .movie)

        print("--- What's playing ---")
        func kind(_ app: String, _ title: String, by artist: String? = nil, album: String? = nil, minutes: Double = 0,
                  video: Bool = false, audio: Bool = false) -> MediaClassifier.Kind {
            MediaClassifier.kind(app: app, title: title, artist: artist, album: album,
                                 duration: minutes > 0 ? minutes * 60 : nil, video: video, audio: audio)
        }
        let chrome = "com.google.Chrome"
        check("a song in Spotify is music", kind("com.spotify.client", "Muththa Mazhai (Reprise)", by: "A.R. Rahman", album: "Thug Life", minutes: 4) == .music)
        check("a podcast episode in Spotify is a podcast", kind("com.spotify.client", "#231 - How to Focus", by: "Huberman Lab", minutes: 95) == .podcast)
        check("an hour of talk in Spotify without an album is a podcast", kind("com.spotify.client", "Monday chat", by: "Some Show", minutes: 60) == .podcast)
        check("Apple Podcasts is a podcast", kind("com.apple.podcasts", "Anything") == .podcast)
        check("Audible is a podcast (an audiobook)", kind("com.audible.iphone", "Chapter 3") == .podcast)
        check("Netflix is a film or show", kind("com.netflix.Netflix", "Stranger Things") == .movie)
        check("the TV app is a film or show", kind("com.apple.TV", "Severance") == .movie)
        check("a YouTube video is a video", kind(chrome, "OUR LAST GTA V VIDEO", by: "MoreSidemen", minutes: 36) == .video)
        check("a music video on YouTube is music", kind(chrome, "Blinding Lights (Official Video)", by: "TheWeekndVEVO", minutes: 4) == .music)
        check("an auto-generated YouTube song is music", kind(chrome, "Kesariya", by: "Arijit Singh - Topic", minutes: 5) == .music)
        check("YouTube Music (it has an album) is music", kind(chrome, "Levitating", by: "Dua Lipa", album: "Future Nostalgia", minutes: 3.4) == .music)
        check("a podcast on YouTube is a podcast", kind(chrome, "The Diary Of A CEO Podcast: Episode 12", by: "DOAC", minutes: 90) == .podcast)
        check("Netflix in a browser is a film or show", kind(chrome, "Wednesday | Netflix", minutes: 50) == .movie)
        check("a two-hour video with no channel is a film", kind(chrome, "Interstellar", minutes: 169, video: true) == .movie)
        check("words like 'deep' don't make it a podcast", kind(chrome, "Deep sleep sounds keep calm", by: "Relax", minutes: 30) == .video)
        check("an unknown audio app playing a short track is music", kind("com.example.player", "Track 1", minutes: 3, audio: true) == .music)

        check("helper reports are read", NowPlaying.state(from: ["playing": true, "app": "com.spotify.client", "type": 1, "artist": "X", "duration": 200])
              == NowPlaying.State(playing: true, app: "com.spotify.client", artist: "X", duration: 200, audio: true))

        print("--- Reacting to each kind ---")
        a.apply(Decision(action: .idle, duration: 1))
        for (m, gear) in [(MediaActivity.movie, MediaGear.movie), (.video, .video), (.podcast, .podcast), (.music, .none)] {
            a.media = m; a.mediaChanged(); a.updateBeat()
            check("\(AudioWatcher.name(m).lowercased()): the pet has the right gear on", a.view.watching == gear)
        }
        a.media = .movie; a.mediaChanged()
        check("during a film the pet keeps quiet", !a.canSpeak(force: false))
        check("during a film it doesn't dance or wear headphones", a.view.musicBpm == 0)
        let film = PetContext(surface: .floor, axisFraction: 0.5, cursorDistance: 900, secondsSinceInteraction: 60, hour: 20,
                              platformAbove: true, canClimb: true, canHide: true, media: .movie, userAway: false, focusing: false,
                              species: a.species, energy: 0.8, fullness: 0.8, joy: 0.8, bondLevel: 3)
        var sitting = 0
        for _ in 0..<1000 { if case .idle = brain.nextDecision(film).action { sitting += 1 } }
        check("during a film it mostly sits still", sitting > 800, "\(sitting / 10)% idle")
        var podcastPicks = Set<String>()
        let talk = PetContext(surface: .floor, axisFraction: 0.5, cursorDistance: 900, secondsSinceInteraction: 60, hour: 20,
                                           platformAbove: false, canClimb: false, canHide: false, media: .podcast, userAway: false, focusing: false,
                                           species: a.species, energy: 0.8, fullness: 0.8, joy: 0.8, bondLevel: 3)
        for _ in 0..<1000 { podcastPicks.insert(String(describing: brain.nextDecision(talk).action).components(separatedBy: "(")[0]) }
        check("during a podcast it never dances or does zoomies", !podcastPicks.contains("dance") && !podcastPicks.contains("zoomies"),
              podcastPicks.sorted().joined(separator: ", "))
        a.media = .none; a.mediaChanged(from: .movie); a.updateBeat()
        check("when it ends the gear comes off", a.view.watching == .none)

        print("--- Acts ---")
        for kind in [MediaActivity.music, .podcast, .video, .movie] {
            check("\(AudioWatcher.name(kind).lowercased()) has five acts", MediaAct.acts(for: kind).count == 5)
        }
        check("every act belongs to exactly one kind (plus five for private windows)", MediaAct.allCases.count == 25 && MediaAct.privacy.count == 5)
        var repeats = 0
        for act in MediaAct.allCases { for _ in 0..<50 where MediaAct.pick(for: act.kind, after: act) == act { repeats += 1 } }
        check("switching acts never picks the same one again", repeats == 0)
        var seen = Set<MediaAct>()
        for _ in 0..<400 { if let p = MediaAct.pick(for: .video) { seen.insert(p) } }
        check("over time every video act turns up", seen.count == 5)
        for kind in [MediaActivity.music, .podcast, .video, .movie] {
            a.media = kind; a.mediaChanged()
            check("\(AudioWatcher.name(kind).lowercased()) starts one of its own acts", a.view.act?.kind == kind, a.view.act?.label ?? "none")
        }
        a.media = .music; a.mediaChanged()
        let firstAct = a.view.act
        a.nextActChange = .distantPast
        a.mediaTick(Date())
        check("after a few minutes it moves on to another act", a.view.act != firstAct && a.view.act?.kind == .music)
        a.view.angle = 0                       // upright: props are put away on walls and the ceiling
        a.view.act = .karaoke; a.view.mood = .idle
        check("singing karaoke it shows the mic, not headphones", a.view.showsAct && !(a.view.act?.wearsHeadphones ?? true))
        a.view.act = .dj
        check("DJing it wears headphones", a.view.act?.wearsHeadphones == true)
        a.view.mood = .walk
        check("a turntable doesn't come along on a walk", !a.view.showsAct)
        a.view.act = .rave
        check("glow sticks do come along on a walk", a.view.showsAct)
        a.view.mood = .idle
        a.media = .none; a.mediaChanged()
        check("when nothing plays there's no act", a.view.act == nil)

        print("--- Private windows ---")
        let chromeID = "com.google.Chrome"
        check("Chrome's incognito placeholder counts as private", MediaClassifier.isPrivate(app: chromeID, title: "A site is playing media", artist: ""))
        check("…even before the artist has cleared", MediaClassifier.isPrivate(app: chromeID, title: "A site is playing media", artist: "MoreSidemen"))
        check("a normal YouTube video isn't private", !MediaClassifier.isPrivate(app: chromeID, title: "SIDEMEN GTA V BINGO", artist: "MoreSidemen"))
        check("another browser's placeholder counts too", MediaClassifier.isPrivate(app: "org.mozilla.firefox", title: "Firefox is playing media", artist: nil))
        check("a song that happens to say 'is playing' isn't private", !MediaClassifier.isPrivate(app: chromeID, title: "My heart is playing music", artist: "Some Band"))
        check("only browsers have private windows", !MediaClassifier.isPrivate(app: "com.spotify.client", title: "A site is playing media", artist: ""))
        let signatures: [(String, MediaAct)] = [(chromeID, .spy), ("org.mozilla.firefox", .masquerade), ("com.apple.Safari", .peekaboo),
                                                ("com.microsoft.edgemac", .sleepMask), ("com.brave.Browser", .turnAway)]
        check("each browser starts with its own act (Chrome spy, Firefox mask, Safari paws, Edge sleep mask, others turn around)",
              signatures.allSatisfy { MediaAct.signature(for: MediaClassifier.Browser(app: $0.0)) == $0.1 })
        var privateRepeats = 0
        for act in MediaAct.privacy { for _ in 0..<40 where MediaAct.pickPrivate(after: act) == act { privateRepeats += 1 } }
        check("it moves on to the other privacy acts without repeating", privateRepeats == 0)

        a.media = .video; a.privately = true; a.mediaChanged()
        check("something private playing: it looks away", a.view.act?.isPrivacy == true, a.view.act?.label ?? "none")
        check("…and the model hears nothing about what it is", a.happeningNow.contains("private window") && !a.happeningNow.contains("video"))
        a.nextActChange = .distantPast
        let firstCover = a.view.act
        a.mediaTick(Date())
        check("…switching to another way of not looking after a while", a.view.act?.isPrivacy == true && a.view.act != firstCover)
        a.view.act = .turnAway; a.view.mood = .idle; a.view.angle = 0
        check("turned around, its face is hidden", a.view.hidesFace)
        a.privately = false; a.mediaChanged()
        check("back in a normal window, a normal video act again", a.view.act?.isPrivacy == false && a.view.act?.kind == .video)
        a.media = .none; a.mediaChanged()

        var settle = AudioWatcher.Settle()
        let t0 = Date()
        check("music from Now Playing starts within half a second",
              settle.feed(.music, exact: true, now: t0) != nil && settle.feed(.music, exact: true, now: t0 + 0.35) == nil && settle.value == .music)
        _ = settle.feed(.none, exact: true, now: t0 + 1)
        check("…and stops within a second of pausing", settle.feed(.none, exact: true, now: t0 + 1.65) == nil && settle.value == .none)
        _ = settle.feed(.music, exact: true, now: t0 + 2)
        _ = settle.feed(.music, exact: true, now: t0 + 2.4)
        _ = settle.feed(.none, exact: true, now: t0 + 3)
        check("the gap between two songs doesn't end the vibe", settle.feed(.music, exact: true, now: t0 + 3.3) == nil && settle.value == .music)
        var fallback = AudioWatcher.Settle()
        check("sound only seen in the speaker list still waits a few seconds",
              fallback.feed(.other, exact: false, now: t0) != nil && fallback.feed(.other, exact: false, now: t0 + 1) != nil
              && fallback.feed(.other, exact: false, now: t0 + 3.1) == nil && fallback.value == .other)
        check("a call still takes a few seconds to count", AudioWatcher.delay(from: .music, to: .call, exact: true) >= 3)

        a.apply(Decision(action: .dance, duration: 6))
        a.media = .music; a.mediaChanged()
        a.media = .none; a.mediaChanged()
        check("a dance stops when the music does", a.remaining <= 0.4, String(format: "%.1fs left", a.remaining))

        // MARK: Two pets
        print("--- Google Calendar ---")
        do {
            func event(_ json: String) -> GoogleEvent? { try? JSONDecoder().decode(GoogleEvent.self, from: Data(json.utf8)) }
            let defaults = [GoogleReminder(method: "popup", minutes: 10)]
            let own = event(#"{"id":"a","summary":"Standup","start":{"dateTime":"2030-01-07T09:00:00+05:30"},"reminders":{"useDefault":false,"overrides":[{"method":"popup","minutes":5},{"method":"email","minutes":30},{"method":"popup","minutes":5}]}}"#)
            let ev = own?.reduced(calendarDefaults: defaults)
            check("an event with its own notifications uses those (30 and 5 min, no repeats)", ev?.reminders == [30, 5], "\(ev?.reminders ?? [])")
            check("a +05:30 start time is read correctly", ev?.start == GoogleTime.parse("2030-01-07T03:30:00Z"))
            let usesDefault = event(#"{"id":"b","summary":"1:1","start":{"dateTime":"2030-01-07T10:00:00Z"},"reminders":{"useDefault":true}}"#)
            check("\"use default\" takes the calendar's default notifications", usesDefault?.reduced(calendarDefaults: defaults)?.reminders == [10])
            let none = event(#"{"id":"c","summary":"Lunch","start":{"dateTime":"2030-01-07T12:00:00Z"},"reminders":{"useDefault":false}}"#)
            check("notifications turned off: no reminders", none?.reduced(calendarDefaults: defaults)?.reminders == [])
            let declined = event(#"{"id":"d","summary":"Optional sync","start":{"dateTime":"2030-01-07T12:00:00Z"},"attendees":[{"self":true,"responseStatus":"declined"}]}"#)
            check("declined events are skipped", declined != nil && declined?.reduced(calendarDefaults: defaults) == nil)
            let cancelled = event(#"{"id":"e","status":"cancelled","start":{"dateTime":"2030-01-07T12:00:00Z"}}"#)
            check("cancelled events are skipped", cancelled != nil && cancelled?.reduced(calendarDefaults: defaults) == nil)
            let allDay = event(#"{"id":"f","summary":"Birthday","start":{"date":"2030-01-08"},"reminders":{"useDefault":true}}"#)?.reduced(calendarDefaults: defaults)
            check("all-day events don't take the timed defaults", allDay?.allDay == true && allDay?.reminders == [])

            let start = Date().addingTimeInterval(3600)
            let meeting = CalendarEvent(id: "m", title: "Design review", start: start, allDay: false, reminders: [30, 5])
            check("alarms at 30 min, 5 min and the start", meeting.alarms(atStart: true).map(\.minutes) == [30, 5, 0])
            check("…or only its own times", meeting.alarms(atStart: false).map(\.minutes) == [30, 5])
            var sched = AlarmSchedule()
            let alarms = meeting.alarms(atStart: true)
            check("nothing an hour ahead", sched.due(alarms, now: start - 3600).isEmpty)
            let at30 = sched.due(alarms, now: start - 1800)
            check("the 30-minute reminder fires on time", at30.map(\.minutes) == [30] && at30.first?.minutesLeft(start - 1800) == 30)
            check("…only once", sched.due(alarms, now: start - 1790).isEmpty)
            check("the 5-minute reminder fires", sched.due(alarms, now: start - 300).map(\.minutes) == [5])
            check("and \"starting now\"", sched.due(alarms, now: start + 1).map(\.minutes) == [0])
            check("nothing after that", sched.due(alarms, now: start + 120).isEmpty)

            var slept = AlarmSchedule()
            let woke = slept.due(alarms, now: start - 600)
            check("asleep through the 30-min one: caught up once, saying the real time left", woke.count == 1 && woke.first?.minutesLeft(start - 600) == 10)
            var late = AlarmSchedule()
            check("an event that already started gets no catch-up", late.due(alarms, now: start + 300).isEmpty)
            let disabled = GoogleCalendar.apiError(403, Data(#"{"error":{"code":403,"message":"Google Calendar API has not been used in project 123 before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/calendar-json.googleapis.com/overview?project=123 then retry.","errors":[{"reason":"accessNotConfigured"}],"details":[{"reason":"SERVICE_DISABLED"}]}}"#.utf8))
            check("a turned-off API says so, with the link to turn it on", disabled.message.contains("turned off") && disabled.message.contains("overview?project=123,"), disabled.message)
            let scope = GoogleCalendar.apiError(403, Data(#"{"error":{"code":403,"message":"Request had insufficient authentication scopes.","errors":[{"reason":"insufficientPermissions"}],"details":[{"reason":"ACCESS_TOKEN_SCOPE_INSUFFICIENT"}]}}"#.utf8))
            check("missing calendar permission says to sign in again and tick the box", scope.message.contains("tick"), scope.message)
            check("anything else shows Google's own words", GoogleCalendar.apiError(500, Data(#"{"error":{"message":"Backend Error"}}"#.utf8)).message.hasSuffix("500: Backend Error"))
            check("long waits read naturally", Dialogue.inTime(90) == "1 hr 30 min" && Dialogue.inTime(1440) == "1 day" && Dialogue.inTime(5) == "5 min")

            // The pet says it, and the same alert from the Mac's Calendar app isn't repeated.
            let c = PetController()
            c.lastSlow = .distantFuture
            let saidBefore = c.saidCount
            let now = Date()
            c.meetingQueue = []; c.recentMeetings = [:]; c.lastMeetingSaid = .distantPast
            c.queueMeeting("Design review", minutes: 5, now)        // from Google
            c.queueMeeting("Design review", minutes: 5, now)        // the same event from the Calendar app
            c.queueMeeting("Standup", minutes: 0, now)
            check("the same alert from both calendars is queued once", c.meetingQueue.count == 2, "\(c.meetingQueue)")
            c.checkCalendar(now)
            check("the pet says the reminder", c.saidCount == saidBefore + 1 && c.lastSaid == "📅 Design review in 5 min!", c.lastSaid)
            c.checkCalendar(now + 2)
            check("a second one waits a few seconds instead of covering the first", c.saidCount == saidBefore + 1)
            c.checkCalendar(now + 9)
            check("…then it's said", c.lastSaid == "📅 Standup is starting now!", c.lastSaid)
        }

        print("--- Two pets ---")
        let b = PetController(isMain: false)
        b.lastSlow = .distantFuture
        a.buddy = b; b.buddy = a
        for kind in SocialKind.allCases {
            a.comeDown(); b.comeDown()
            for _ in 0..<90 { a.tick(CGFloat(dt)); b.tick(CGFloat(dt)) }
            a.apply(Decision(action: .idle, duration: 1)); b.apply(Decision(action: .idle, duration: 1))
            b.surface = .ceiling; b.snap(b.screenFrame)            // start the other one hanging from the top
            a.debug(.meet(kind))
            let before = a.meetings
            var simulated = 0.0
            for _ in 0..<(40 * 30) {
                a.tick(CGFloat(dt)); b.tick(CGFloat(dt)); simulated += dt
                if a.meetings > before, a.social == .none, b.social == .none { break }
            }
            check("\(kind.label): the other is called down from the top, then they meet", a.meetings > before && a.social == .none && b.social == .none,
                  String(format: "after %.0fs, then %@ / %@", simulated, String(describing: a.action), String(describing: b.action)))
        }

        // Left alone, do they find each other without being told to?
        a.meetings = 0; b.meetings = 0
        for _ in 0..<(10 * 60 * 30) { a.tick(CGFloat(dt)); b.tick(CGFloat(dt)) }
        check("left alone for 10 minutes, they meet at least 4 times", a.meetings + b.meetings >= 4 && a.isOnScreen() && b.isOnScreen(), "\(a.meetings + b.meetings) meetings")

        print("--- Voice ---")
        do {
            func wake(_ t: String, _ name: String = "Mochi") -> String? { WakePhrase.command(in: t, name: name) }
            check("\"Hey Mochi, do a dance\" gives the request", wake("Hey Mochi, do a dance.") == "do a dance", wake("Hey Mochi, do a dance.") ?? "nil")
            check("the wake phrase on its own gives an empty request", wake("Hey Mochi") == "")
            check("hi / okay / hello work too", wake("hi mochi sleep") == "sleep" && wake("OK, Mochi! Treat?") == "treat" && wake("hello mochi") == "")
            check("a misheard name still counts (mochie, mocha)", wake("hey mochie dance") == "dance" && wake("hey mocha spin") == "spin")
            check("the name opening the sentence counts", wake("Mochi, come here") == "come here")
            check("a word or two of noise before it is fine", wake("um hey mochi stretch") == "stretch")
            check("the name in the middle of a sentence doesn't wake it", wake("I love eating mochi ice cream") == nil)
            check("nor does a different word", wake("hey mocking bird") == nil && wake("hey there") == nil)
            check("short names must match exactly", wake("hey bob", "Bo") == nil && wake("hey bo dance", "Bo") == "dance")
            check("two-word names", wake("hey captain paws dance", "Captain Paws") == "dance", wake("hey captain paws dance", "Captain Paws") ?? "nil")
            check("every species' own name wakes it", Species.allCases.allSatisfy { wake("hey \($0.name) dance", $0.name) == "dance" },
                  Species.allCases.filter { wake("hey \($0.name) dance", $0.name) != "dance" }.map(\.name).joined(separator: ", "))

            func local(_ t: String) -> String { LocalCommands.match(t)?.action ?? "-" }
            let expected: [(String, String)] = [("do a dance", "dance"), ("can I give you a treat", "treat"), ("go to sleep", "sleep"),
                ("wake up", "wake"), ("come here", "come"), ("come down from there", "come_down"), ("play fetch", "ball"),
                ("do a backflip", "flip"), ("spin around", "spin"), ("start a focus session", "focus"), ("stop focus", "stop_focus"),
                ("how was my day", "check_in"), ("show me your power move", "power"), ("hello", "talk"), ("thank you", "talk")]
            let wrong = expected.filter { local($0.0) != $0.1 }.map { "\($0.0) → \(local($0.0))" }
            check("simple requests are understood without AI", wrong.isEmpty, wrong.joined(separator: "; "))
            check("something it doesn't know isn't guessed", LocalCommands.match("what's the capital of France") == nil)
            check("focus minutes from digits and words", LocalCommands.match("focus for 50 minutes")?.minutes == 50
                  && LocalCommands.match("twenty five minute focus")?.minutes == 25 && LocalCommands.match("focus")?.minutes == 25)
            let water = LocalCommands.match("remind me to drink water every hour")
            check("a reminder request, with its interval", water?.action == "reminder" && water?.value == "water" && water?.minutes == 60,
                  "\(water.map { "\($0.action) \($0.value ?? "") \($0.minutes ?? -1)" } ?? "nil")")
            check("numbers: an hour, 2 hours, ninety", LocalCommands.number(in: ["an", "hour"]) == 60 && LocalCommands.number(in: ["2", "hours"]) == 120
                  && LocalCommands.number(in: ["ninety"]) == 90)

            // The pet: listening, the words, then the answer, all in its bubble.
            let v = PetController()
            v.lastSlow = .distantFuture
            v.comeDown()
            for _ in 0..<120 { v.tick(CGFloat(dt)) }
            v.apply(Decision(action: .sleep, duration: 60))
            v.hear(.wake)
            check("\"Hey Mochi\" wakes it up and it listens", v.lastSaid == "👂 Yes?" && v.action != .sleep, "\(v.lastSaid) / \(v.action)")
            v.hear(.partial("do a"))
            check("the words show while they're being said", v.lastSaid == "\u{201C}do a\u{201D}", v.lastSaid)
            v.hear(.heard("do a dance"))
            check("without AI, a spoken request is carried out and answered", v.action == .dance && v.lastSaid == "Watch my moves! 💃", "\(v.action) / \(v.lastSaid)")
            v.hear(.heard("what is the meaning of life"))
            check("a request it doesn't know says what was heard", v.lastSaid.contains("meaning of life") && v.lastSaid.contains("AI"), v.lastSaid)
            v.hear(.nothing)
            check("nothing heard says so", v.lastSaid.contains("didn't catch"))
            let chattiness = s.chattiness
            s.chattiness = .off
            v.hear(.ready)
            check("it answers even with speech bubbles set to silent (you asked)", v.lastSaid.hasPrefix("👂"))
            s.chattiness = chattiness
            v.stop()

            // Who listens when: a pretend engine records what it is told.
            final class FakeEngine: SpeechEngine {
                var onEvent: ((VoiceEvent) -> Void)?
                var log: [String] = []
                func listenOnce(name: String, source: VoiceSource) { log.append("once \(name)") }
                func startWake(name: String, source: VoiceSource) { log.append("wake \(name)") }
                func stop() { log.append("stop") }
            }
            let fake = FakeEngine()
            let vc = VoiceControl(engine: fake)
            var events: [VoiceEvent] = []
            vc.onEvent = { events.append($0) }
            vc.setWake(true, name: "Mochi")
            check("turning on \"Hey Mochi\" starts listening", fake.log == ["wake Mochi"], fake.log.joined(separator: ", "))
            vc.call(true, quiet: false)
            check("with \"Stay quiet during calls\" off, a call doesn't stop it", vc.wakeRunning)
            vc.call(true, quiet: true)
            check("with it on, a call stops it", fake.log.last == "stop" && !vc.wakeRunning)
            vc.call(true, quiet: false)
            check("switching the setting off mid-call starts it again", vc.wakeRunning && fake.log.last == "wake Mochi")
            vc.call(true, quiet: true)
            vc.block("lock"); vc.call(false, quiet: true)
            check("…and it stays off while the screen is locked", !vc.wakeRunning)
            vc.unblock("lock")
            check("…then starts again", vc.wakeRunning && fake.log.last == "wake Mochi")
            vc.setWake(true, name: "Rex")
            check("a new pet listens for its own name", fake.log.suffix(2) == ["stop", "wake Rex"], fake.log.joined(separator: ", "))
            fake.log = []
            vc.listenOnce(name: "Rex")
            check("Talk to… pauses the wake listening and listens once", fake.log == ["stop", "once Rex"], fake.log.joined(separator: ", "))
            fake.onEvent?(.heard("dance"))
            check("the request reaches the pet, then wake listening resumes", events.last == .heard("dance") && vc.wakeRunning && fake.log.last == "wake Rex",
                  fake.log.joined(separator: ", "))
            fake.onEvent?(.failed("no microphone"))
            check("if listening fails it switches itself off instead of retrying", !vc.wakeRunning && events.last == .failed("no microphone"))
            vc.unblock("anything")
            check("…and stays off", !vc.wakeRunning)
        }

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
