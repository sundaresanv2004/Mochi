#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Things the Debug page can ask the pet to do.
enum DebugAction {
    case reminder(ReminderKind)
    case stretch
    case calendar
    case checkIn
    case skip(minutes: Int)         // move every reminder clock forward
    case meet(SocialKind)
    case nextScreen
}

/// Live state for the Debug settings page, refreshed once a second by the main pet.
final class PetDebug: ObservableObject {
    static let shared = PetDebug()

    /// "Next in 12:34", "Off"… keyed by reminder (`ReminderKind.rawValue`, or "stretch").
    @Published var reminders: [String: String] = [:]
    @Published var reminderState = "Starting…"
    @Published var presence = ""
    @Published var sound = ""
    @Published var soundApps: [String] = []
    @Published var pets = ""
    @Published var petState = ""
    @Published var screens = ""
    @Published var claude = ""

    var fire: ((DebugAction) -> Void)?
}

extension PetController {
    func debug(_ a: DebugAction) {
        touch()
        switch a {
        case .reminder(let kind):
            fireReminder(kind)
        case .stretch:
            fireStretch()
        case .calendar:
            say(Dialogue.meeting("Design review", minutes: 5), force: true, seconds: 7)
            if canAct { apply(Decision(action: .happy, duration: 2)) }
        case .checkIn:
            checkIn()
        case .skip(let minutes):
            let jump = TimeInterval(minutes * 60)
            for kind in ReminderKind.allCases where settings.interval(kind) != nil {
                reminderElapsed[kind, default: 0] += jump
            }
            activeSeconds += jump
            lastReminder = .distantPast
        case .meet(let kind):
            guard buddy != nil else { return }
            forcedSocial = kind
            social = .none
            visitWait = 0
        case .nextScreen:
            crossToNextScreen()
        }
        publishDebug(idle: SystemInfo.userIdleSeconds(), Date())
    }

    func publishDebug(idle: TimeInterval, _ now: Date) {
        guard isMain else { return }
        let d = PetDebug.shared

        func countdown(_ elapsed: TimeInterval, _ minutes: Int) -> String {
            let left = Int(TimeInterval(minutes * 60) - elapsed)
            if left <= 0 { return "Due now" }
            return String(format: "Next in %d:%02d", left / 60, left % 60)
        }
        var r: [String: String] = [:]
        for kind in ReminderKind.allCases {
            if let every = settings.interval(kind) {
                r[kind.rawValue] = countdown(reminderElapsed[kind] ?? 0, every)
            } else {
                r[kind.rawValue] = "Off"
            }
        }
        r["stretch"] = settings.breakReminders ? countdown(activeSeconds, settings.breakMinutes) : "Off"
        d.reminders = r

        if let why = remindersBlocked { d.reminderState = "Held back: \(why)" }
        else if idle >= 300 { d.reminderState = "Paused: no input for \(Int(idle / 60)) min" }
        else { d.reminderState = "Counting" }

        d.presence = userAway ? "Away (no input for \(Int(idle / 60)) min)" : "Here, last input \(Int(idle))s ago"

        let heard = audio.current
        var sound = AudioWatcher.name(heard)
        if heard != media {
            sound += settings.reactToMedia ? " (ignored: other sound is switched off in Behavior)" : " (ignored: reactions are off)"
        }
        if audio.onCall { sound += settings.quietOnCalls ? " + on a call" : " + on a call (ignored: Stay quiet during calls is off)" }
        d.sound = sound
        d.soundApps = audio.sources
        let c = claude.snapshot
        if !settings.claudeAware { d.claude = "Off in Behavior" }
        else if let status = Self.claudeStatus(c, now: now) {
            var lines = [status]
            if let u = c.usage { lines.append("Limits from \(u.source) at \(ClaudeWatcher.clock(u.observed))") }
            if !c.liveCheck.isEmpty { lines.append("Last check: \(c.liveCheck)") }
            if !claudeQueue.isEmpty { lines.append("Waiting to say: \(claudeQueue.map(\.line).joined(separator: " / "))") }
            d.claude = lines.joined(separator: "\n")
        } else { d.claude = "Claude Code isn't set up on this \(Computer.name)" }

        // Why the pet is doing what it is doing, in plain words.
        var why: [String] = []
        if userAway { why.append("asleep because you're away") }
        if onCall { why.append("quiet for a call") }
        if media == .video { why.append("watching a video") }
        if media == .movie { why.append("watching a film in 3D glasses, keeping quiet") }
        if media == .podcast { why.append("listening to a podcast") }
        if view.musicBpm > 0 { why.append("vibing to the music") }
        if focusing { why.append("calm for a focus session") }
        if mind.energy < 0.25 { why.append("tired") }
        if mind.fullness < 0.2 { why.append("hungry") }
        if mind.joy < 0.25 { why.append("lonely") }
        d.petState = "\(action) on the \(surface), next decision in \(max(0, Int(remaining)))s"
            + (why.isEmpty ? "" : "\n" + why.joined(separator: ", "))
        let all = NSScreen.screens
        d.screens = all.count == 1 ? "One display" : "On display \((all.firstIndex(of: currentScreen) ?? 0) + 1) of \(all.count)"

        if let b = buddy {
            let mine = social == .none ? "free" : "\(socialKind.label.lowercased()) (\(social))"
            let wait = max(0, Int(min(visitWait, b.visitWait)))
            d.pets = "\(species.name): \(mine) · \(b.species.name): \(b.social == .none ? "free" : "\(b.social)") · next try in \(wait)s"
        } else {
            d.pets = "Second pet is off (turn it on in Pet)"
        }
    }
}
