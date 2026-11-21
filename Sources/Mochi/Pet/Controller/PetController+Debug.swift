import AppKit

/// Things the Debug page can ask the pet to do.
enum DebugAction {
    case reminder(ReminderKind)
    case stretch
    case calendar
    case checkIn
    case skip(minutes: Int)         // move every reminder clock forward
    case meet(SocialKind)
    case nextScreen

    /// What the button was, for the event log.
    var label: String {
        switch self {
        case .reminder(let k): return "\(k.label) reminder"
        case .stretch: return "stretch break"
        case .calendar: return "calendar alert"
        case .checkIn: return "daily check-in"
        case .skip(let m): return "skip reminder clocks \(m) min ahead"
        case .meet(let k): return "meeting: \(k.label.lowercased())"
        case .nextScreen: return "send to next display"
        }
    }
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

    var fire: ((DebugAction) -> Void)?
}

extension PetController {
    func debug(_ a: DebugAction) {
        touch()
        DebugLog.add(.system, "Debug page: \(a.label)")
        switch a {
        case .reminder(let kind):
            fireReminder(kind)
        case .stretch:
            fireStretch()
        case .calendar:
            say(Dialogue.meeting("Design review", minutes: 5), force: true, seconds: 7)
            if canAct { apply(Decision(action: .happy, duration: 2), why: "Debug page") }
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

        // Log only when the clocks change state (counting, paused, held back), not every second.
        let state: String
        if let why = remindersBlocked { state = "Held back: \(why)" }
        else if idle >= 300 { state = "Paused: no input" }
        else { state = "Counting" }
        if d.reminderState != "Starting…", !d.reminderState.hasPrefix(state) {
            DebugLog.add(.reminder, "Reminder clocks: \(state.lowercased())")
        }
        d.reminderState = state == "Paused: no input" ? "\(state) for \(Int(idle / 60)) min" : state

        d.presence = userAway ? "Away (no input for \(Int(idle / 60)) min)" : "Here, last input \(Int(idle))s ago"

        let heard = audio.current
        var sound = AudioWatcher.name(heard)
        if heard != media {
            sound += settings.reactToMedia ? " (ignored: other sound is switched off in Behavior)" : " (ignored: reactions are off)"
        }
        if audio.musicOn, heard != .music { sound += " + music" }
        d.sound = sound
        d.soundApps = audio.sources

        // Why the pet is doing what it is doing, in plain words.
        var why: [String] = []
        if userAway { why.append("asleep because you're away") }
        if media == .call { why.append("quiet for a call") }
        if media == .video { why.append("watching a video") }
        if view.musicBpm > 0 { why.append("vibing to the music") }
        if focusing { why.append("calm for a focus session") }
        if mind.energy < 0.25 { why.append("tired") }
        if mind.fullness < 0.2 { why.append("hungry") }
        if mind.joy < 0.25 { why.append("lonely") }
        d.petState = "\(action.label(on: surface).capitalizingFirst) on the \(surface.label), next decision in \(max(0, Int(remaining)))s"
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
