import AppKit

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
        a.media = .call
        pass(700, idle: 2)
        check("held back during a call", a.saidCount == said && (a.reminderElapsed[.water] ?? 0) >= 600)
        a.media = .none
        pass(2, idle: 2)
        check("fires as soon as the call ends", a.saidCount == said + 1)
        a.reminderElapsed = [:]; a.media = .call; said = a.saidCount
        pass(905, idle: 2)
        check("a call only delays it by 5 minutes", a.saidCount == said + 1)
        a.media = .none

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
        let logged = DebugLog.shared.recorded
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

        // MARK: Event log
        print("--- Debug page event log ---")
        let events = DebugLog.shared.entries.suffix(DebugLog.shared.recorded - logged)
        let kinds = Dictionary(grouping: events, by: \.category).mapValues(\.count)
        print("events in 20 minutes: " + kinds.sorted { $0.value > $1.value }.map { "\($0.key.label) \($0.value)" }.joined(separator: ", "))
        check("every decision from the brain is logged with where it came from",
              events.contains { $0.category == .decision && $0.message.hasSuffix("· instincts") })
        check("whatever the pet says is logged", kinds[.speech, default: 0] >= a.saidCount - said, "\(kinds[.speech, default: 0]) for \(a.saidCount - said) said")
        check("actions are logged in plain words", !events.contains { $0.message.contains("(axis:") })
        let perMinute = Double(DebugLog.shared.recorded - logged) / 20
        check("the log stays readable (under 40 events a minute)", perMinute < 40, String(format: "%.0f a minute", perMinute))
        check("the log keeps at most \(DebugLog.capacity) events", DebugLog.shared.entries.count <= DebugLog.capacity)

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

        // Spotify playing while a Discord voice channel holds the mic: the call wins `current`, but it's still music.
        AudioWatcher.shared.musicOn = true
        a.media = .call
        a.mediaChanged()
        a.view.mood = .idle
        check("music during a call (e.g. a Discord voice channel) still gets the vibe", a.view.vibing && a.view.musicBpm > 0)
        check("…while the pet stays quiet for the call", !a.canSpeak(force: false))
        AudioWatcher.shared.musicOn = false
        a.updateBeat()
        check("the vibe ends when that music stops", a.view.musicBpm == 0)
        a.media = .none
        a.mediaChanged()

        // MARK: Two pets
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

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
