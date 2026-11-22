import Foundation
#if canImport(Combine)
import Combine
#else
import AppKitLite
#endif

/// How a species leans. 1 = average; higher = more of it.
struct Personality {
    var playful: Double     // dancing, zoomies, spins
    var sleepy: Double      // naps more, tires faster
    var curious: Double     // looking around, climbing, leaping onto windows
    var cuddly: Double      // comes over to the cursor
    var appetite: Double    // gets hungry faster
}

/// The headline feeling shown in the menu and settings.
enum Feeling {
    case sleepy, hungry, lonely, joyful, content

    var label: String {
        switch self {
        case .sleepy: return "Sleepy"
        case .hungry: return "Hungry"
        case .lonely: return "Lonely"
        case .joyful: return "Joyful"
        case .content: return "Content"
        }
    }

    /// SF Symbol shown next to the feeling in the menu and settings.
    var symbol: String {
        switch self {
        case .sleepy: return "moon.zzz.fill"
        case .hungry: return "fork.knife"
        case .lonely: return "cloud.rain.fill"
        case .joyful: return "sparkles"
        case .content: return "leaf.fill"
        }
    }
}

/// The pet's inner state: needs that drift over time and a bond that grows as you look after it.
/// Saved to UserDefaults, so the pet remembers you between launches.
final class PetMind: ObservableObject {
    static let shared = PetMind()
    static let maxLevel = 6

    @Published private(set) var energy: Double      // 0 exhausted … 1 rested
    @Published private(set) var fullness: Double    // 0 starving … 1 stuffed
    @Published private(set) var joy: Double         // 0 lonely … 1 delighted
    @Published private(set) var bondXP: Double

    let firstMet: Date
    /// True the very first time the app runs.
    let isNew: Bool
    /// How long the app was closed before this launch.
    let awaySeconds: TimeInterval
    /// Called with the new level when the bond levels up.
    var onLevelUp: ((Int) -> Void)?

    private let d = UserDefaults.standard
    private var lastPetXP = Date.distantPast
    private var sinceSave: TimeInterval = 0

    private init() {
        let now = Date()
        isNew = d.object(forKey: "mind.firstMet") == nil
        firstMet = d.object(forKey: "mind.firstMet") as? Date ?? now
        var e = d.object(forKey: "mind.energy") as? Double ?? 0.8
        var f = d.object(forKey: "mind.fullness") as? Double ?? 0.6
        var j = d.object(forKey: "mind.joy") as? Double ?? 0.7
        bondXP = d.object(forKey: "mind.bondXP") as? Double ?? 0

        // While the app was closed the pet rested, got a bit peckish and missed you (gently: never punishing).
        let away = max(0, now.timeIntervalSince(d.object(forKey: "mind.lastSeen") as? Date ?? now))
        awaySeconds = away
        if away > 60 {
            e = min(1, e + away / 1800)
            f = max(min(f, 0.3), f - away / 14_400)
            j = max(min(j, 0.35), j - away / 43_200)
        }
        energy = e; fullness = f; joy = j
    }

    // MARK: Derived

    var level: Int { min(Self.maxLevel, Int((bondXP / 12).squareRoot()) + 1) }

    /// 0…1 progress towards the next bond level (1 at max level).
    var levelProgress: Double {
        let l = Double(level)
        guard level < Self.maxLevel else { return 1 }
        let lo = 12 * (l - 1) * (l - 1), hi = 12 * l * l
        return (bondXP - lo) / (hi - lo)
    }

    var bondTitle: String { Self.title(level) }

    static func title(_ level: Int) -> String {
        ["New friend", "Buddy", "Friend", "Good friend", "Best friend", "Soulmate"][max(1, min(maxLevel, level)) - 1]
    }

    var daysTogether: Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: firstMet), to: cal.startOfDay(for: Date())).day ?? 0
        return days + 1
    }

    var feeling: Feeling {
        if energy < 0.2 { return .sleepy }
        if fullness < 0.2 { return .hungry }
        if joy < 0.25 { return .lonely }
        if joy > 0.7 { return .joyful }
        return .content
    }

    var isStuffed: Bool { fullness > 0.95 }

    // MARK: Time passing

    /// `exertion`: 1 = pottering about, more when running or dancing.
    func tick(_ dt: TimeInterval, asleep: Bool, exertion: Double, personality p: Personality) {
        if asleep {
            energy += dt / 360                          // a full recharge takes about six minutes of sleep
            fullness -= dt / 10_800 * p.appetite
        } else {
            energy -= dt / 2700 * exertion * p.sleepy   // about 45 minutes of pottering
            fullness -= dt / 5400 * p.appetite          // peckish after about an hour and a half
            joy -= dt / 6000 * (fullness < 0.2 ? 2 : 1)     // lonely after an hour or so without attention
        }
        clampAll()
        sinceSave += dt
        if sinceSave >= 30 { save() }
    }

    // MARK: Things that happen to the pet

    func petted() {
        joy += 0.06
        let now = Date()
        if now.timeIntervalSince(lastPetXP) > 20 {      // click-spamming doesn't farm the bond
            lastPetXP = now
            addBond(1)
        }
        clampAll()
    }

    func fed() { fullness += 0.35; joy += 0.1; addBond(4); clampAll() }
    func played() { joy += 0.25; energy -= 0.08; addBond(5); clampAll() }
    func enjoyedMusic(_ dt: TimeInterval) { joy += dt / 900; clampAll() }
    func focusedTogether() { joy += 0.1; addBond(6); clampAll() }
    func reunitedWithBuddy() { joy += 0.04; clampAll() }
    func reunited() { joy += 0.15; addBond(2); clampAll() }

    func save() {
        sinceSave = 0
        d.set(firstMet, forKey: "mind.firstMet")
        d.set(energy, forKey: "mind.energy")
        d.set(fullness, forKey: "mind.fullness")
        d.set(joy, forKey: "mind.joy")
        d.set(bondXP, forKey: "mind.bondXP")
        d.set(Date(), forKey: "mind.lastSeen")
    }

    private func addBond(_ xp: Double) {
        let before = level
        bondXP += xp
        if level > before { onLevelUp?(level) }
    }

    private func clampAll() {
        energy = min(1, max(0, energy))
        fullness = min(1, max(0, fullness))
        joy = min(1, max(0, joy))
    }
}
