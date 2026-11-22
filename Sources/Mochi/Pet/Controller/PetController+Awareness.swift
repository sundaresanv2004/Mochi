#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Once-a-second awareness: needs, idle, battery, load, reminders and calendar (sound is in +Media).
extension PetController {
    func slowTick(_ now: Date) {
        let elapsed = now.timeIntervalSince(lastSlow)
        guard elapsed >= 1 else { return }
        lastSlow = now

        // Needs drift: resting restores energy, running about burns it.
        let exertion: Double
        switch action {
        case .zoomies, .dance, .chase: exertion = 3
        case .walk: exertion = 1.2
        default: exertion = ball != nil ? 3 : 0.7
        }
        let step = min(elapsed, 5)
        if isMain {
            mind.tick(step, asleep: action == .sleep, exertion: exertion, personality: species.personality)
            if media == .music, action != .sleep { mind.enjoyedMusic(step) }
            if let end = focusEnds, now >= end { finishFocus() }
        }

        refreshMedia()
        mediaTick(now)

        // Is anyone there?
        let idle = SystemInfo.userIdleSeconds()
        if idle > 180, !userAway {
            userAway = true
            if canAct { action = .sleep; remaining = 600 }
        } else if userAway, idle < 5 {
            userAway = false
            welcomeBack()
        }

        guard isMain else { return }              // everything below is the main pet's job
        log.tick(step, userActive: idle < 60)

        // Been working a long time?
        if idle < 300 { activeSeconds += step } else if idle > 600 { activeSeconds = 0 }
        if settings.breakReminders, mayRemind(overdue: activeSeconds - TimeInterval(settings.breakMinutes * 60)) {
            fireStretch(now)
        }
        checkReminders(step, idle: idle, now)
        checkCalendar(now)
        claudeTick(now)
        if now.timeIntervalSince(lastDiaryCheck) > 300 { lastDiaryCheck = now; PetAI.shared.diaryIfDue(log) }
        publishDebug(idle: idle, now)

        if settings.systemAware { checkHour(); checkBattery(now); checkLoad(now) }
        else { view.sweat = false; view.shiver = false }
    }

    func welcomeBack() {
        guard isMain else { return }
        log.tookBreak()
        react("Your human just came back to the \(Computer.name) after a few minutes away", fallback: "Welcome back! 👋")
        view.spawnHearts(3)
        if canAct { apply(Decision(action: .happy, duration: 2)) }
    }

    func checkHour() {
        let h = hour
        defer { lastHour = h }
        guard lastHour != -1, h != lastHour else { return }
        switch h {
        case 12: react("It just turned noon: lunch time", fallback: "Lunch time! 🍱")
        case 17: react("It just turned 5 pm: the working day is nearly over", fallback: "Almost done for the day? 🌇")
        case 18: if settings.dailyCheckIn { say(log.current.summary(prefix: "Today"), seconds: 7) }
        case 22: react("It just turned 10 pm and your human is still at the \(Computer.name)", fallback: "Getting late… bedtime soon? 🌙")
        case 0: react("It is past midnight and your human is still at the \(Computer.name)", fallback: "It's past midnight! Time to sleep? 😴", note: true)
        default: break
        }
    }

    func checkBattery(_ now: Date) {
        guard now.timeIntervalSince(lastBattery) >= 30 else { return }
        lastBattery = now
        guard let b = SystemInfo.battery() else { return }
        if let was = wasCharging, !was, b.charging {
            react("The \(Computer.name)'s charger was just plugged in", fallback: "Ahh, power! ⚡")
            view.spawnHearts(2)
        }
        wasCharging = b.charging
        if b.level <= 15, !b.charging, !batteryWarned {
            batteryWarned = true
            react("The \(Computer.name)'s battery is down to \(b.level)% and it is not charging: ask to be plugged in and mention the number",
                  fallback: "Battery's at \(b.level)%. Plug me in? 🔋", force: true)
        }
        if b.charging || b.level > 30 { batteryWarned = false }
        view.shiver = b.level <= 10 && !b.charging      // running on fumes
    }

    /// Busy Mac: sweat while the processor is flat out, and say so if it goes on.
    func checkLoad(_ now: Date) {
        let gap = now.timeIntervalSince(lastCPUCheck)
        guard gap >= 5 else { return }
        lastCPUCheck = now
        guard let cur = SystemInfo.cpuTicks() else { return }
        defer { lastCPU = cur }
        guard let prev = lastCPU, cur.total > prev.total else { return }
        let load = (cur.busy - prev.busy) / (cur.total - prev.total)

        busySeconds = load > 0.8 ? busySeconds + gap : 0
        view.sweat = busySeconds >= 10
        if busySeconds >= 25, now > busyCooldown, canAct, action != .sleep {
            busyCooldown = now.addingTimeInterval(600)
            react("The \(Computer.name)'s processor has been working flat out for half a minute, something heavy is running",
                  fallback: Dialogue.busyMac.randomElement() ?? "Phew!")
        }
        let state = ProcessInfo.processInfo.thermalState
        if state == .serious || state == .critical {
            view.sweat = true
            if now > hotCooldown {
                hotCooldown = now.addingTimeInterval(900)
                react("The \(Computer.name) is running hot", fallback: Dialogue.hotMac.randomElement() ?? "It's warm in here!")
            }
        }
    }

    // MARK: Gentle reminders and calendar

    /// Why reminders are being held back right now (nil = nothing in the way).
    var remindersBlocked: String? {
        if onCall { return "you're on a call" }
        if focusEnds != nil { return "a focus session is running" }
        if userAway { return "you're away" }
        return nil
    }

    /// A reminder that is due waits for a focus session to end and for you to come back. It waits for a call
    /// too, but only five minutes: a bubble is silent, and some people sit in a voice channel for hours.
    func mayRemind(overdue: TimeInterval) -> Bool {
        guard overdue >= 0, focusEnds == nil, !userAway else { return false }
        return !onCall || overdue >= 300
    }

    /// Each reminder counts the time you are at your Mac. Reading or watching without touching anything
    /// still counts; the clock pauses once you have been gone five minutes and starts over after fifteen.
    func checkReminders(_ dt: TimeInterval, idle: TimeInterval, _ now: Date) {
        if idle > 900 { reminderElapsed.removeAll(); return }     // a proper break: start over
        guard idle < 300 else { return }                          // stepped away: pause
        for kind in ReminderKind.allCases {
            guard let every = settings.interval(kind) else { reminderElapsed[kind] = nil; continue }
            reminderElapsed[kind, default: 0] += dt
            guard mayRemind(overdue: reminderElapsed[kind, default: 0] - TimeInterval(every * 60)),
                  now.timeIntervalSince(lastReminder) > 45 else { continue }      // never two nudges on top of each other
            fireReminder(kind, now)
        }
    }

    /// Show a reminder now and restart its clock.
    func fireReminder(_ kind: ReminderKind, _ now: Date = Date()) {
        reminderElapsed[kind] = 0
        lastReminder = now
        if action == .sleep, canAct { action = .idle; remaining = 1 }     // wake up to say it
        view.spawnHearts(1)
        if canAct {
            switch kind {
            case .water: apply(Decision(action: .happy, duration: 1.6))
            case .posture: apply(Decision(action: .stretch, duration: 2.6))
            case .eyes: apply(Decision(action: .lookAround, duration: 3))
            }
        }
        // Said last, so nothing the action says ("*yaaawn*") can replace the reminder.
        say(Dialogue.reminder(kind).randomElement() ?? kind.label, force: true, seconds: 7)
    }

    func fireStretch(_ now: Date = Date()) {
        activeSeconds = 0
        lastReminder = now
        if canAct { apply(Decision(action: .stretch, duration: 3)) }
        say("You've been at it for a while. Time to stretch! 🧘", force: true, seconds: 7)
    }

    /// Calendar alerts from two places: Google Calendar (each event's own notification times, checked every
    /// second) and the calendars on this Mac (five minutes ahead and at the start, checked every 30 s).
    /// When both have the same event, it is said once; several at once are said one after another.
    func checkCalendar(_ now: Date) {
        if settings.googleCalendarAlerts {
            for a in GoogleCalendar.shared.due(now: now) { queueMeeting(a.title, minutes: a.minutesLeft(now), now) }
        }
        if settings.calendarAlerts, now.timeIntervalSince(lastCalendarCheck) >= 30 {
            lastCalendarCheck = now
            for a in calendar.due(now: now) { queueMeeting(a.title, minutes: a.minutes, now) }
        }
        guard !meetingQueue.isEmpty, now.timeIntervalSince(lastMeetingSaid) >= 8 else { return }
        lastMeetingSaid = now
        let line = meetingQueue.removeFirst()
        if action == .sleep, canAct { action = .idle; remaining = 1 }     // wake up to say it
        if canAct { apply(Decision(action: .happy, duration: 2)) }
        say(line, force: true, seconds: 8)                                // said last, so nothing replaces it
    }

    func queueMeeting(_ title: String, minutes: Int, _ now: Date) {
        let key = "\(title.lowercased())|\(minutes)"
        recentMeetings = recentMeetings.filter { now.timeIntervalSince($0.value) < 180 }
        guard recentMeetings[key] == nil else { return }
        recentMeetings[key] = now
        meetingQueue.append(Dialogue.meeting(title, minutes: minutes))
    }

    /// Turns calendar alerts on, asking macOS for access the first time. `done(false)` means access was refused.
    func enableCalendar(_ done: @escaping (Bool) -> Void) { calendar.requestAccess(done) }
}
