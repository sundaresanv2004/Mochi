import Foundation
#if canImport(Combine)
import Combine
#else
import AppKitLite
#endif

/// What the pet remembers: a short list of facts about its human, a diary with one entry per day,
/// and a scratch list of things that happened today (the raw material for tonight's entry).
/// Saved as one small JSON file in Application Support; nothing here is sent anywhere except as
/// part of a prompt to the AI server you chose.
final class PetMemory: ObservableObject {
    static let shared = PetMemory()
    static let maxFacts = 30
    static let maxEntries = 30

    struct Entry: Codable, Identifiable, Equatable {
        var day: String
        var text: String
        var id: String { day }
    }

    private struct Store: Codable {
        var facts: [String] = []
        var diary: [Entry] = []
        var events: [String: [String]] = [:]
    }

    @Published private(set) var facts: [String] = []
    @Published private(set) var diary: [Entry] = []            // newest first
    private var events: [String: [String]] = [:]
    private let file: URL

    private init() {
        file = PetAI.dataDir.appendingPathComponent("memory.json")
        if let data = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(Store.self, from: data) {
            facts = s.facts; diary = s.diary; events = s.events
        }
    }

    private func save() {
        // Only today's and yesterday's happenings are worth keeping.
        let keep = Set(events.keys.sorted().suffix(2))
        events = events.filter { keep.contains($0.key) }
        if let data = try? JSONEncoder().encode(Store(facts: facts, diary: diary, events: events)) {
            try? data.write(to: file, options: .atomic)
        }
    }

    // MARK: Facts

    /// Adds a fact unless it is already known. Returns false for a duplicate or an empty string.
    @discardableResult
    func remember(_ fact: String) -> Bool {
        let f = String(fact.trimmingCharacters(in: .whitespacesAndNewlines).prefix(140))
        guard f.count > 2, !facts.contains(where: { $0.caseInsensitiveCompare(f) == .orderedSame }) else { return false }
        facts.append(f)
        if facts.count > Self.maxFacts { facts.removeFirst(facts.count - Self.maxFacts) }
        save()
        return true
    }

    /// Forgets every fact that mentions `words`. Returns how many went.
    @discardableResult
    func forget(matching words: String) -> Int {
        let w = words.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !w.isEmpty else { return 0 }
        let before = facts.count
        facts.removeAll { $0.lowercased().contains(w) }
        if facts.count != before { save() }
        return before - facts.count
    }

    func forget(at index: Int) {
        guard facts.indices.contains(index) else { return }
        facts.remove(at: index)
        save()
    }

    func forgetEverything() {
        facts = []; diary = []; events = [:]
        save()
    }

    /// The facts as prompt text (most recent last), or nil when there are none.
    var factsForPrompt: String? {
        facts.isEmpty ? nil : facts.suffix(12).map { "- \($0)" }.joined(separator: "\n")
    }

    // MARK: Today's happenings

    /// Jot down something that happened, for tonight's diary. Repeats within a day are dropped.
    func note(_ event: String, day: String = DailyLog.key()) {
        var list = events[day] ?? []
        guard !list.contains(where: { $0.hasSuffix(": " + event) }), list.count < 40 else { return }
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        list.append("\(time): \(event)")
        events[day] = list
        save()
    }

    func happenings(on day: String) -> [String] { events[day] ?? [] }

    // MARK: Diary

    func hasEntry(for day: String) -> Bool { diary.contains { $0.day == day } }

    func write(_ text: String, for day: String) {
        diary.removeAll { $0.day == day }
        diary.append(Entry(day: day, text: text))
        diary.sort { $0.day > $1.day }
        if diary.count > Self.maxEntries { diary.removeLast(diary.count - Self.maxEntries) }
        save()
    }
}
