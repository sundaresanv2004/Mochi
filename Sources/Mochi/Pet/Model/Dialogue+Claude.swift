import Foundation

/// What the pet says about Claude Code working and about its plan limits.
extension Dialogue {
    /// "45s", "12 min", "1h 5m".
    static func duration(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60) min" }
        let m = (s % 3600) / 60
        return m == 0 ? "\(s / 3600)h" : "\(s / 3600)h \(m)m"
    }

    /// " on Mochi", or " in 2 sessions".
    static func claudeWhere(_ project: String?, sessions: Int) -> String {
        if sessions > 1 { return " in \(sessions) sessions" }
        return project.map { " on \($0.prefix(24))" } ?? ""
    }

    static func claudeStarted(_ project: String?, sessions: Int) -> [String] {
        let on = claudeWhere(project, sessions: sessions)
        return ["Claude is working\(on) 🤖", "Claude's on it\(on)! 🤖", "Ooh, Claude is busy\(on) ✨"]
    }

    static func claudeWorking(_ elapsed: TimeInterval, _ project: String?, sessions: Int) -> [String] {
        let t = duration(elapsed), on = claudeWhere(project, sessions: sessions)
        return ["Claude's been working\(on) for \(t) ⏱️", "Still going: Claude, \(t) so far 🤖", "\(t) of Claude\(on) and counting ⏳"]
    }

    static func claudeDone(_ took: TimeInterval, _ project: String?) -> [String] {
        let t = duration(took), on = project.map { " on \($0.prefix(24))" } ?? ""
        return ["Claude finished\(on) after \(t) ✅", "Claude's done\(on)! That took \(t) ✨", "Done\(on)! \(t) of Claude 🎉"]
    }

    /// "resets in 2h 10m", or for a week "resets Mon 8:30 PM".
    static func claudeResets(_ date: Date?, now: Date) -> String {
        guard let date, date > now else { return "" }
        let left = date.timeIntervalSince(now)
        if left < 20 * 3600 { return "resets in \(duration(left))" }
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return "resets \(f.string(from: date))"
    }

    /// A warning each time a limit passes another 10%, more urgent the higher it gets.
    static func claudeLimit(weekly: Bool, percent: Int, resets: Date?, now: Date) -> String {
        let name = weekly ? "weekly limit" : "5-hour limit"
        let r = claudeResets(resets, now: now)
        let tail = r.isEmpty ? "" : " (\(r))"
        switch percent {
        case 100...: return "Claude's \(name) is used up! 🛑\(r.isEmpty ? "" : " It " + r)"
        case 90...: return "⚠️ Claude's \(name) is at \(percent)%! Nearly out\(tail)"
        case 70...: return "Careful: Claude's \(name) is at \(percent)%\(tail) 👀"
        case 50...: return "Claude's \(name) is half gone: \(percent)%\(tail)"
        default: return "Claude's used \(percent)% of its \(name)\(tail) 🤖"
        }
    }
}
