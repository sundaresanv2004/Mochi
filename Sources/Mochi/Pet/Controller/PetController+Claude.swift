#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Claude Code (see `ClaudeWatcher`): the pet says when Claude starts on something, how long it has been
/// at it every few minutes, and when it's done; and each time the 5-hour or weekly limit passes another 10%.
/// Quick answers (under 20 seconds) are left alone. Limit warnings are like reminders: they wait until
/// you're back and a focus session is over, and only the urgent ones (80% and up) talk over a call.
extension PetController {
    static let claudeAnnounceAfter: TimeInterval = 20
    static let claudeUpdateEvery: TimeInterval = 5 * 60

    /// Once a second, on the main pet. `snapshot` stands in for the watcher in tests.
    func claudeTick(_ now: Date, _ snapshot: ClaudeWatcher.Snapshot? = nil) {
        guard settings.claudeAware else { return }
        let s = snapshot ?? claude.snapshot
        let project = s.sessions.last?.project ?? claudeProject
        let count = s.sessions.count

        if let first = s.sessions.map(\.since).min() {
            if claudeBusySince == nil {
                claudeBusySince = min(first, now)
                claudeAnnounced = false
            }
            claudeProject = count == 1 ? project : nil
            let elapsed = now.timeIntervalSince(claudeBusySince!)
            if !claudeAnnounced, elapsed >= Self.claudeAnnounceAfter {
                claudeAnnounced = true
                claudeNextUpdate = now.addingTimeInterval(Self.claudeUpdateEvery)
                react("Claude Code, the AI coding assistant, started working on a task for your human\(Dialogue.claudeWhere(project, sessions: count))",
                      fallback: Dialogue.claudeStarted(project, sessions: count).randomElement()!, seconds: 4.5)
                if canAct, !userAway, action == .idle || action == .lookAround { apply(Decision(action: .happy, duration: 1.4)) }
            } else if claudeAnnounced, now >= claudeNextUpdate {
                claudeNextUpdate = now.addingTimeInterval(Self.claudeUpdateEvery)
                say(Dialogue.claudeWorking(elapsed, project, sessions: count).randomElement()!, seconds: 4.5)
            }
        } else if let since = claudeBusySince {
            claudeBusySince = nil
            let took = max(0, (s.lastActivity ?? now).timeIntervalSince(since))
            if claudeAnnounced, took >= 60 {
                react("Claude Code just finished the task it was working on for your human, after \(Dialogue.duration(took)): say how long it took",
                      fallback: Dialogue.claudeDone(took, project).randomElement()!, seconds: 5)
                if canAct, !userAway { apply(Decision(action: .happy, duration: 1.6)) }
            }
            claudeAnnounced = false
            claudeProject = nil
        }

        if settings.claudeLimitAlerts, let u = s.usage {
            let before = claudeAlerts.marks
            for (key, weekly, window) in [("five_hour", false, u.fiveHour), ("seven_day", true, u.weekly)] {
                guard let window, let step = claudeAlerts.update(key, window) else { continue }
                let line = Dialogue.claudeLimit(weekly: weekly, percent: step * 10, resets: window.resetsAt, now: now)
                // Passed two steps while you were away: only the latest is worth saying.
                claudeQueue.removeAll { $0.key == key }
                claudeQueue.append((key, line, step >= 8))
            }
            if claudeAlerts.marks != before { claudeAlerts.save() }
        }
        sayClaudeWarning(now)
    }

    /// The next limit warning, once there's a moment for it.
    func sayClaudeWarning(_ now: Date) {
        guard let next = claudeQueue.first, now.timeIntervalSince(lastClaudeLine) >= 8,
              now.timeIntervalSince(lastReminder) > 8, !userAway, focusEnds == nil || next.urgent,
              !onCall || next.urgent else { return }
        claudeQueue.removeFirst()
        lastClaudeLine = now
        if action == .sleep, canAct { action = .idle; remaining = 1 }       // wake up to say it
        if canAct { apply(Decision(action: next.urgent ? .lookAround : .happy, duration: 2)) }
        say(next.line, force: true, seconds: 7)                            // said last, so nothing replaces it
    }

    /// One line for the menu and the Debug page: "Working on Mochi for 12 min · 5h 19% · week 43%".
    static func claudeStatus(_ s: ClaudeWatcher.Snapshot, now: Date = Date()) -> String? {
        guard s.installed else { return nil }
        var parts: [String] = []
        if let first = s.sessions.map(\.since).min() {
            parts.append("Working\(Dialogue.claudeWhere(s.sessions.last?.project, sessions: s.sessions.count)) for \(Dialogue.duration(now.timeIntervalSince(first)))")
        } else {
            parts.append("Idle")
        }
        if let f = s.usage?.fiveHour { parts.append("5h \(Int(f.used))%") }
        if let w = s.usage?.weekly { parts.append("week \(Int(w.used))%") }
        return parts.joined(separator: " · ")
    }
}
