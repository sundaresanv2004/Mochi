import Foundation
import Combine

/// A short history of what the pets did and why, shown on the Debug page.
///
/// Kept in memory only (the last `capacity` entries) and never written to disk unless you save it from
/// the Debug page. Adding an entry is cheap and safe from any thread, so anything can call `DebugLog.add`.
/// Only things that happen now and then are recorded, never anything that happens every frame.
final class DebugLog: ObservableObject {
    static let shared = DebugLog()
    static let capacity = 500

    enum Category: String, CaseIterable, Identifiable {
        case decision, speech, ai, media, reminder, social, movement, system

        var id: String { rawValue }

        var label: String {
            switch self {
            case .decision: return "Decisions"
            case .speech: return "Speech"
            case .ai: return "AI"
            case .media: return "Sound"
            case .reminder: return "Reminders"
            case .social: return "Two pets"
            case .movement: return "Movement"
            case .system: return "System"
            }
        }

        /// SF Symbol for the category.
        var symbol: String {
            switch self {
            case .decision: return "arrow.triangle.branch"
            case .speech: return "text.bubble.fill"
            case .ai: return "sparkles"
            case .media: return "speaker.wave.2.fill"
            case .reminder: return "bell.fill"
            case .social: return "person.2.fill"
            case .movement: return "figure.walk"
            case .system: return "gearshape.fill"
            }
        }
    }

    struct Entry: Identifiable {
        let id: Int
        let time: Date
        let category: Category
        /// Which pet it is about (nil for things that concern the whole app).
        let pet: String?
        let message: String
        /// Longer text shown when the entry is expanded: a prompt and reply, the apps playing sound…
        let detail: String?
    }

    @Published private(set) var entries: [Entry] = []
    /// How many entries were ever recorded (the list itself keeps only the last `capacity`).
    private(set) var recorded = 0

    /// Record something. Safe to call from any thread; the entry is added on the main thread.
    static func add(_ category: Category, _ message: String, pet: String? = nil, detail: String? = nil) {
        let time = Date()
        if Thread.isMainThread {
            shared.append(time, category, pet, message, detail)
        } else {
            DispatchQueue.main.async { shared.append(time, category, pet, message, detail) }
        }
    }

    private func append(_ time: Date, _ category: Category, _ pet: String?, _ message: String, _ detail: String?) {
        entries.append(Entry(id: recorded, time: time, category: category, pet: pet, message: message, detail: detail))
        recorded += 1
        if entries.count > Self.capacity { entries.removeFirst(entries.count - Self.capacity) }
    }

    func clear() { entries.removeAll() }

    // MARK: Exporting

    static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// Plain text for a bug report: one line per entry, details indented underneath.
    static func text(_ list: [Entry]) -> String {
        list.map { e in
            var line = "\(clock.string(from: e.time))  [\(e.category.label)]  "
            if let pet = e.pet { line += "\(pet): " }
            line += e.message
            if let d = e.detail, !d.isEmpty {
                line += "\n" + d.split(separator: "\n", omittingEmptySubsequences: false).map { "        " + $0 }.joined(separator: "\n")
            }
            return line
        }.joined(separator: "\n")
    }
}

extension PetAction {
    /// The action in plain words, for the Debug page ("walk right", "climb the edge").
    func label(on surface: Surface) -> String {
        switch self {
        case .idle: return "idle"
        case .walk(let axis):
            switch surface {
            case .leftWall, .rightWall: return axis > 0 ? "climb up" : "climb down"
            case .ceiling: return axis > 0 ? "crawl right" : "crawl left"
            default: return axis > 0 ? "walk right" : "walk left"
            }
        case .sleep: return "sleep"
        case .chase: return "chase the cursor"
        case .happy: return "happy bounce"
        case .greet: return "say hello"
        case .leap: return "leap onto a window"
        case .stretch: return "stretch"
        case .spin: return "spin"
        case .dance: return "dance"
        case .lookAround: return "look around"
        case .zoomies: return "zoomies"
        case .climbEdge: return "head for the edge"
        case .dizzy: return "dizzy"
        case .mope: return "mope"
        case .hide: return "hide and peek"
        case .visit: return "visit the other pet"
        case .power: return "power move"
        case .flip: return "backflip"
        }
    }
}

extension Surface {
    var label: String {
        switch self {
        case .floor: return "floor"
        case .leftWall: return "left edge"
        case .rightWall: return "right edge"
        case .ceiling: return "top edge"
        case .air: return "air"
        }
    }
}

extension String {
    /// "walk right" → "Walk right".
    var capitalizingFirst: String { prefix(1).uppercased() + dropFirst() }
}
