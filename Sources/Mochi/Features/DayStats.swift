import Foundation
#if canImport(Combine)
import Combine
#else
import AppKitLite
#endif

/// What happened on one day. Only counts and durations: nothing about what you typed or did.
struct DayStats: Codable, Equatable {
    var day: String
    var activeSeconds: Double = 0       // time you were at the Mac
    var typingSeconds: Double = 0
    var focusSessions = 0
    var focusMinutes = 0
    var breaks = 0                      // times you stepped away for a few minutes and came back
    var treats = 0
    var pets = 0
    var plays = 0

    var isEmpty: Bool { activeSeconds < 60 && focusSessions == 0 && treats + pets + plays == 0 }

    static func minutes(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    /// One friendly sentence for the pet to say.
    func summary(prefix: String) -> String {
        if isEmpty { return "\(prefix): a quiet one so far. I'm here when you need me!" }
        var parts: [String] = []
        if typingSeconds >= 60 { parts.append("\(Self.minutes(typingSeconds)) typing") }
        if focusSessions > 0 { parts.append("\(focusSessions) focus session\(focusSessions == 1 ? "" : "s")") }
        if breaks > 0 { parts.append("\(breaks) break\(breaks == 1 ? "" : "s")") }
        if parts.isEmpty { parts.append("\(Self.minutes(activeSeconds)) at your Mac") }
        let care = treats + pets + plays
        let tail = breaks == 0 && activeSeconds > 2 * 3600 ? " Take a break soon?" : (care > 0 ? " Thanks for looking after me 💖" : " Nice work ✨")
        return "\(prefix): \(parts.joined(separator: ", ")).\(tail)"
    }
}

/// Keeps today's and yesterday's stats, saved in UserDefaults.
final class DailyLog: ObservableObject {
    static let shared = DailyLog()

    @Published private(set) var today: DayStats
    @Published private(set) var yesterday: DayStats?

    private let d = UserDefaults.standard
    private var work: DayStats                  // edited every second; published now and then
    private var sincePublish: TimeInterval = 0

    static func key(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func load(_ name: String) -> DayStats? {
        guard let data = UserDefaults.standard.data(forKey: name) else { return nil }
        return try? JSONDecoder().decode(DayStats.self, from: data)
    }

    private init() {
        let key = Self.key()
        var t = Self.load("stats.today") ?? DayStats(day: key)
        var y = Self.load("stats.yesterday")
        if t.day != key {
            y = t
            t = DayStats(day: key)
        }
        today = t
        work = t
        yesterday = y
    }

    /// True when yesterday's stats are from the calendar day right before today.
    var hasFreshYesterday: Bool {
        guard let y = yesterday, !y.isEmpty,
              let prev = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return false }
        return y.day == Self.key(prev)
    }

    /// Call about once a second. Rolls the day over at midnight and saves now and then.
    func tick(_ dt: TimeInterval, userActive: Bool) {
        let key = Self.key()
        if work.day != key {
            yesterday = work
            work = DayStats(day: key)
            publish()
        }
        if userActive { work.activeSeconds += dt }
        sincePublish += dt
        if sincePublish >= 15 { publish() }
    }

    func typed(_ seconds: TimeInterval) { work.typingSeconds += seconds }
    func focused(minutes: Int) { work.focusSessions += 1; work.focusMinutes += minutes; publish() }
    func tookBreak() { work.breaks += 1; publish() }
    func gaveTreat() { work.treats += 1; publish() }
    func petted() { work.pets += 1 }
    func played() { work.plays += 1; publish() }

    /// The live numbers (the published copy can be a few seconds behind).
    var current: DayStats { work }

    func publish() {
        sincePublish = 0
        if today != work { today = work }
        let enc = JSONEncoder()
        if let data = try? enc.encode(work) { d.set(data, forKey: "stats.today") }
        if let y = yesterday, let data = try? enc.encode(y) { d.set(data, forKey: "stats.yesterday") }
    }
}
