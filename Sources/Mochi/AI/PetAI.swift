import Foundation
#if canImport(Combine)
import Combine
#else
import AppKitLite
#endif

/// What the model asked the pet to do in answer to something you typed.
struct PetCommand {
    var action: String
    var minutes: Int?
    var value: String?
    var say: String?
}

/// Everything the pet uses a language model for. Each feature is optional and falls back to the
/// built-in behaviour when AI is off, the server is unreachable, or the reply makes no sense:
///
/// 1. fresh lines for every moment the pet speaks (`restyle`)
/// 2. remarks about what is going on right now (`reaction`)
/// 3. now and then, choosing what to do next (`decide`, used by `LLMBrain`)
/// 4. little conversations between two pets (`banter`)
/// 5. understanding typed requests (`command`)
/// 6. a diary and a few remembered facts (`diaryIfDue`)
///
/// Everything here runs on the main thread except the network calls themselves.
final class PetAI: ObservableObject {
    static let shared = PetAI()

    enum Feature { case dialogue, reactions, brain, banter, memory, commands }

    /// Set by the developer tests so a simulated day never calls a real server.
    var suspended = false

    @Published private(set) var lastError: String?
    @Published private(set) var lastReply: Date?
    @Published private(set) var models: [String] = []
    @Published private(set) var testing = false
    @Published private(set) var testResult: String?
    @Published private(set) var writingDiary = false

    private let settings = PetSettings.shared
    private let memory = PetMemory.shared
    private let mind = PetMind.shared
    /// After a failed call, background requests wait a minute instead of hammering a server that is down.
    private var downUntil = Date.distantPast

    private var client: LLMClient {
        LLMClient(baseURL: settings.aiBaseURL, model: settings.aiModel, apiKey: settings.aiKey)
    }

    var ready: Bool {
        settings.aiEnabled && !suspended
            && !settings.aiModel.trimmingCharacters(in: .whitespaces).isEmpty
            && !settings.aiBaseURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func on(_ f: Feature) -> Bool {
        guard ready else { return false }
        switch f {
        case .dialogue: return settings.aiDialogue
        case .reactions: return settings.aiReactions
        case .brain: return settings.aiBrain
        case .banter: return settings.aiBanter
        case .memory: return settings.aiMemory
        case .commands: return settings.aiCommands
        }
    }

    /// Runs `work` off the main thread and hands the result (nil on any failure) back on it.
    private func run<T>(urgent: Bool = false, _ work: @escaping (LLMClient) async throws -> T?,
                        done: @escaping (T?) -> Void) {
        guard ready, urgent || Date() >= downUntil else { done(nil); return }
        let c = client
        Task.detached { [self] in
            do {
                let value = try await work(c)
                await MainActor.run {
                    self.lastError = nil
                    self.lastReply = Date()
                    done(value)
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.downUntil = Date().addingTimeInterval(60)
                    done(nil)
                }
            }
        }
    }

    // MARK: Who the pet is

    private func traits(_ s: Species) -> String {
        let p = s.personality
        var t: [String] = []
        if p.playful > 1.3 { t.append("very playful") } else if p.playful < 0.9 { t.append("laid-back") }
        if p.sleepy > 1.15 { t.append("sleepy") } else if p.sleepy < 0.6 { t.append("tireless") }
        if p.curious > 1.3 { t.append("curious") }
        if p.cuddly > 1.1 { t.append("cuddly") } else if p.cuddly < 0.8 { t.append("a bit aloof") }
        if p.appetite > 1.3 { t.append("always hungry") }
        if s.style == .tough { t.append("acts tough but is soft underneath") }
        return t.joined(separator: ", ")
    }

    private func persona(_ s: Species, remember: Bool = true) -> String {
        var out = """
        You are \(s.name), a tiny \(s.rawValue) who lives on your human's Mac screen as a desktop pet. \
        Character: \(s.tagline.lowercased()); \(traits(s)). You walk along the Dock, climb the screen edges, \
        nap, dance to music and love treats (\(s.treatEmoji)) and pets.
        You speak in tiny speech bubbles: first person, warm, in character, plain words, at most one emoji, \
        never quotation marks, never hashtags, never mention being an AI or a model.
        You and your human are "\(mind.bondTitle.lowercased())" after \(mind.daysTogether) day\(mind.daysTogether == 1 ? "" : "s") together.
        """
        if remember, settings.aiMemory, let facts = memory.factsForPrompt {
            out += "\nThings you remember about your human:\n\(facts)"
        }
        return out
    }

    /// How the pet is and what time it is, in a sentence the model can use.
    func situation() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, h:mm a"
        func level(_ v: Double, _ low: String, _ mid: String, _ high: String) -> String { v < 0.3 ? low : (v > 0.7 ? high : mid) }
        return "It is \(f.string(from: Date())). You feel \(mind.feeling.label.lowercased()): "
            + level(mind.energy, "tired", "fairly rested", "full of energy") + ", "
            + level(mind.fullness, "hungry", "not hungry", "well fed") + ", "
            + level(mind.joy, "a bit lonely", "content", "very happy") + "."
    }

    // MARK: 1. Fresh lines

    private var pools: [String: [String: [String]]] = PetAI.loadPools()       // species → moment → lines
    private var lookup: [Species: [String: Dialogue.Moment]] = [:]            // canned line → its moment
    private var uses: [String: Int] = [:]
    private var writing = Set<String>()
    private var retryAfter: [String: Date] = [:]
    private var lastGiven = ""

    /// Where the written lines and the memory file live. The developer test uses a throwaway folder.
    static let dataDir: URL = {
        let root = CommandLine.arguments.contains("--ai-test")
            ? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mochi-ai-test-\(ProcessInfo.processInfo.processIdentifier)")
            : (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
               ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("Mochi", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }()

    private static var poolFile: URL { dataDir.appendingPathComponent("lines.json") }

    private static func loadPools() -> [String: [String: [String]]] {
        guard let data = try? Data(contentsOf: poolFile) else { return [:] }
        return (try? JSONDecoder().decode([String: [String: [String]]].self, from: data)) ?? [:]
    }

    private func savePools() {
        if let data = try? JSONEncoder().encode(pools) { try? data.write(to: Self.poolFile, options: .atomic) }
    }

    var generatedLineCount: Int { pools.values.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } } }

    /// Throw away every generated line; they are written again as the pet needs them.
    func clearLines() {
        pools = [:]; uses = [:]; retryAfter = [:]
        savePools()
        objectWillChange.send()
    }

    /// If `text` is one of the canned lines, swap in a model-written line for the same moment.
    /// The first time a moment comes up the canned line is used and fresh ones are ordered for next time.
    func restyle(_ text: String, species s: Species) -> String {
        guard on(.dialogue) else { return text }
        if lookup[s] == nil {
            var map: [String: Dialogue.Moment] = [:]
            for m in Dialogue.moments(for: s) { for l in m.lines where map[l] == nil { map[l] = m } }
            lookup[s] = map
        }
        guard let moment = lookup[s]?[text] else { return text }
        let id = "\(s.rawValue)/\(moment.key)"
        let pool = pools[s.rawValue]?[moment.key] ?? []
        guard !pool.isEmpty else { write(moment, for: s); return text }

        // Once each line has been heard a couple of times, order a new batch.
        uses[id, default: 0] += 1
        if uses[id, default: 0] >= pool.count * 2 { write(moment, for: s) }
        let fresh = pool.filter { $0 != lastGiven }
        lastGiven = (fresh.isEmpty ? pool : fresh).randomElement() ?? text
        return lastGiven
    }

    private func write(_ m: Dialogue.Moment, for s: Species) {
        let id = "\(s.rawValue)/\(m.key)"
        guard !writing.contains(id), Date() >= (retryAfter[id] ?? .distantPast) else { return }
        writing.insert(id)
        let longest = m.lines.map { $0.split(separator: " ").count }.max() ?? 6
        let words = max(3, longest + 2)
        let system = persona(s, remember: false)
        let user = """
        Write 10 different things you might say in this moment: \(m.about).
        Examples of the length and tone (write new ones, do not copy): \(m.lines.prefix(4).joined(separator: " | "))
        Each line: at most \(words) words, at most one emoji, all different from each other.
        Reply with only a JSON array of 10 strings.
        """
        run({ c in
            let reply = try await c.chat(system: system, user: user, maxTokens: 500, temperature: 1.0)
            var list = LLMClient.json(in: reply)
            if let dict = list as? [String: Any] { list = dict.values.first { $0 is [Any] } }
            let lines = (list as? [Any] ?? []).compactMap { $0 as? String }
                .compactMap { LLMClient.line($0, limit: 80) }
                .filter { $0.split(separator: " ").count <= words + 4 }
            return lines.count >= 4 ? Array(Set(lines)) : nil
        }, done: { [weak self] (lines: [String]?) in
            guard let self else { return }
            self.writing.remove(id)
            guard let lines else {
                self.retryAfter[id] = Date().addingTimeInterval(600)
                return
            }
            self.pools[s.rawValue, default: [:]][m.key] = lines
            self.uses[id] = 0
            self.savePools()
            self.objectWillChange.send()
        })
    }

    // MARK: 2. Remarks about what is going on

    /// One short line about `event`. `done(nil)` if the model takes longer than `patience` seconds
    /// (the pet then says its canned line instead; a late answer is dropped).
    /// 15 s leaves room for a local model on a laptop (a short line can take ~8 s, longer if a
    /// background request is still running); the moment is usually still current by then.
    func reaction(to event: String, species s: Species, extra: String = "", patience: TimeInterval = 15,
                  done: @escaping (String?) -> Void) {
        guard on(.reactions) else { done(nil); return }
        var finished = false
        func finish(_ line: String?) {
            guard !finished else { return }
            finished = true
            done(line)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + patience) { finish(nil) }
        let system = persona(s)
        let user = """
        \(situation())\(extra.isEmpty ? "" : " " + extra)
        What just happened: \(event)
        Say one short line about it, at most 14 words. Reply with just the line.
        """
        run(urgent: true, { c in
            LLMClient.line(try await c.chat(system: system, user: user, maxTokens: 220, urgent: true))
        }, done: finish)
    }

    // MARK: 3. Choosing what to do

    private static let moves: [(name: String, hint: String, action: PetAction, seconds: ClosedRange<TimeInterval>)] = [
        ("idle", "stand and watch", .idle, 3...6),
        ("walk", "wander along", .walk(axis: 1), 3...7),
        ("nap", "curl up and sleep", .sleep, 12...25),
        ("happy", "bounce happily", .happy, 1.5...2),
        ("stretch", "yawn and stretch", .stretch, 2.4...2.4),
        ("spin", "twirl", .spin, 0.9...0.9),
        ("flip", "backflip", .flip, 0.8...0.8),
        ("dance", "dance", .dance, 4...7),
        ("look_around", "glance about", .lookAround, 3...3),
        ("zoomies", "sprint back and forth", .zoomies, 3...4),
        ("power", "signature power move", .power, 2.2...2.2),
        ("chase_cursor", "run to the mouse cursor", .chase, 3...6),
        ("climb", "climb the screen edge", .climbEdge, 10...14),
        ("hide", "hide behind the screen edge and peek", .hide, 14...16),
        ("leap", "jump onto the window above", .leap, 2...2)
    ]

    /// Ask the model what the pet feels like doing. `done(nil)` means "let the built-in brain choose".
    func decide(_ ctx: PetContext, recent: [String], done: @escaping (Decision?) -> Void) {
        guard on(.brain) else { done(nil); return }
        let grounded = ctx.surface == .floor
        let options = Self.moves.filter { m in
            switch m.action {
            case .climbEdge: return ctx.canClimb
            case .hide: return ctx.canHide
            case .leap: return ctx.platformAbove && grounded
            case .spin, .flip, .zoomies: return grounded
            case .chase: return ctx.cursorDistance < 700 && settings.followCursor
            default: return true
            }
        }
        let media: String
        switch ctx.media {
        case .music: media = " Music is playing: you vibe along to it whatever you do, so there's no need to dance all the time."
        case .podcast: media = " Your human is listening to a podcast: stay calm, no dancing."
        case .video: media = " Your human is watching a video: you're watching too."
        case .movie: media = " Your human is watching a film: you're watching too, so stay still and calm."
        case .other: media = " Some sound is playing."
        default: media = ""
        }
        let system = persona(ctx.species)
        let user = """
        \(situation())\(media) You are on the \(grounded ? "ground" : "edge of the screen"). \
        Your human last played with you \(Int(ctx.secondsSinceInteraction / 60)) minutes ago.
        Recently you did: \(recent.isEmpty ? "nothing much" : recent.joined(separator: ", ")).
        Pick what you feel like doing next. Options: \(options.map { "\($0.name) (\($0.hint))" }.joined(separator: ", ")).
        Fit your mood and character, and avoid repeating yourself. About half the time also say a short line \
        (at most 10 words) that goes with it; otherwise leave "say" empty.
        Reply with only JSON: {"action": "<option>", "say": "<line or empty>"}
        """
        let axis: CGFloat = ctx.axisFraction < 0.12 ? 1 : (ctx.axisFraction > 0.88 ? -1 : (Bool.random() ? 1 : -1))
        run({ c in
            let reply = try await c.chat(system: system, user: user, maxTokens: 260)
            guard let obj = LLMClient.json(in: reply) as? [String: Any],
                  let name = (obj["action"] as? String)?.lowercased().replacingOccurrences(of: " ", with: "_"),
                  let move = options.first(where: { $0.name == name }) else { return nil }
            var action = move.action
            if case .walk = action { action = .walk(axis: axis) }
            return Decision(action: action, duration: .random(in: move.seconds),
                            line: (obj["say"] as? String).flatMap { LLMClient.line($0, limit: 80) })
        }, done: done)
    }

    // MARK: 4. Two pets talking

    /// What two pets talk about. Most of it is about their human.
    enum BanterTopic: String, CaseIterable {
        case hello, human, humanDay, now, petLife

        var instruction: String {
            switch self {
            case .hello: return "A just ran over to say hello to B. They greet each other and chat a little."
            case .human: return "They gossip fondly about their human: habits, likes and quirks they have noticed."
            case .humanDay: return "They talk about how their human's day is going and what their human has been up to."
            case .now: return "They talk about what is going on on the \(Computer.name) right now."
            case .petLife: return "They talk about their own pet life: snacks, naps, games, dreams, the view from the Dock."
            }
        }
    }

    /// Recent conversations, so the model doesn't write the same one twice.
    private var recentBanter: [[String]] = []

    /// What the pets know about their human for a conversation: remembered facts, today's numbers and
    /// what happened today. Facts and happenings only when Memory is switched on.
    func humanNotes() -> (facts: String?, today: String?) {
        let t = DailyLog.shared.today
        var day: [String] = []
        if !t.isEmpty {
            day.append("At the \(Computer.name) for \(DayStats.minutes(t.activeSeconds)) so far today, typing for \(DayStats.minutes(t.typingSeconds)); "
                + "\(t.focusSessions) focus session(s); \(t.breaks) break(s); "
                + "\(t.treats) treat(s), \(t.pets) pet(s) and \(t.plays) ball game(s) given to the pets.")
        }
        if settings.aiMemory { day += memory.happenings(on: t.day).suffix(6) }
        return (settings.aiMemory ? memory.factsForPrompt : nil,
                day.isEmpty ? nil : day.map { "- \($0)" }.joined(separator: "\n"))
    }

    /// A topic for a chat, weighted towards the human when there is something to say about them.
    func pickBanterTopic(now: String) -> BanterTopic {
        let notes = humanNotes()
        var options: [(Double, BanterTopic)] = [(1, .petLife)]
        if notes.facts != nil { options.append((3, .human)) }
        if notes.today != nil { options.append((3, .humanDay)) }
        if !now.isEmpty { options.append((2, .now)) }
        if options.count == 1 { options.append((2, .human)) }     // nothing known yet: they wonder about their human
        var roll = Double.random(in: 0..<options.reduce(0) { $0 + $1.0 })
        for (weight, topic) in options {
            roll -= weight
            if roll < 0 { return topic }
        }
        return .petLife
    }

    /// A short conversation, alternating, starting with `a` (the one who ran over). `now` is what is
    /// going on on the Mac (music, a focus session…).
    func banter(_ a: Species, _ b: Species, topic: BanterTopic = .hello, now: String = "", count: Int = 4,
                done: @escaping ([String]?) -> Void) {
        guard on(.banter) else { done(nil); return }
        let notes = humanNotes()
        let order = (0..<count).map { $0 % 2 == 0 ? "A" : "B" }.joined(separator: ", ")
        let system = "You write tiny, charming dialogues between two desktop pets who live on someone's \(Computer.name) screen and adore their human."
        var user = """
        A is \(a.name) the \(a.rawValue) (\(a.tagline.lowercased()); \(traits(a))).
        B is \(b.name) the \(b.rawValue) (\(b.tagline.lowercased()); \(traits(b))).
        \(situation().components(separatedBy: ". ").first ?? "").\(now.isEmpty ? "" : " " + now)
        They are standing together on the Dock, where their human can see them.
        """
        if let f = notes.facts { user += "\nWhat they know about their human:\n\(f)" }
        if let d = notes.today { user += "\nTheir human's day so far:\n\(d)" }
        user += "\nTopic: \(topic.instruction)"
        if let last = recentBanter.last { user += "\nDon't repeat their last chat: \(last.joined(separator: " / "))" }
        user += """

        Write a \(count)-line exchange: \(order). Each line at most \(count > 4 ? 12 : 9) words, playful, in character, \
        at most one emoji, no speaker names inside the lines. Be warm about the human, never mean, and only mention \
        things about the human listed above; don't invent facts about them.
        Reply with only a JSON array of \(count) strings.
        """
        run(urgent: true, { c in
            let reply = try await c.chat(system: system, user: user, maxTokens: 120 + count * 60, temperature: 1.0, urgent: true)
            var list = LLMClient.json(in: reply)
            if let dict = list as? [String: Any] { list = dict.values.first { $0 is [Any] } }
            let lines = (list as? [Any] ?? []).compactMap { $0 as? String }.compactMap { raw -> String? in
                var s = raw
                for label in ["A:", "B:", "\(a.name):", "\(b.name):"] where s.hasPrefix(label) { s.removeFirst(label.count) }
                return LLMClient.line(s, limit: 90)
            }
            return lines.count >= 2 ? Array(lines.prefix(count)) : nil
        }, done: { [weak self] lines in
            if let lines, let self {
                self.recentBanter.append(lines)
                if self.recentBanter.count > 3 { self.recentBanter.removeFirst() }
            }
            done(lines)
        })
    }

    // MARK: 5. Typed requests

    static let commandGuide = """
    none (just talk: answer a question or chat), treat (drop a snack for yourself), ball (start a ball game), \
    come (run to the mouse cursor), sleep, wake, dance, spin, flip, zoomies, stretch, power (signature move), \
    trick (a random trick), hide, climb (climb the screen edge), go_left, go_right (walk to that end of the screen), \
    come_down (drop to the ground), bring_back (reappear if lost), visit (go and see the other pet), \
    check_in (report how today went), focus (start a focus session; "minutes"), stop_focus, \
    reminder ("value": water, posture or eyes; "minutes": how often, 0 turns it off), \
    stretch_reminder ("minutes": how often, 0 turns it off), outfit ("value": what to wear), \
    size ("value": small, medium or large), speech ("value": silent, quiet, normal or chatty), \
    second_pet ("value": on or off), remember ("value": a fact about your human to keep, in third person), \
    forget ("value": a word or phrase to forget)
    """

    /// Turn something the human typed into one action plus a spoken reply.
    func command(_ text: String, species s: Species, extra: String, done: @escaping (PetCommand?) -> Void) {
        guard on(.commands) else { done(nil); return }
        let system = persona(s) + """

        Your human can type to you. Work out what they want and answer with one action and a short spoken reply.
        Actions: \(Self.commandGuide)
        Reply with only JSON: {"action": "<action>", "minutes": <number, only if needed>, "value": "<text, only if needed>", \
        "say": "<your reply, at most 18 words>"}
        If they just want to talk, use "none" and answer in "say". If you cannot do what they ask, use "none" and say so kindly.
        """
        let user = "\(situation()) \(extra)\nYour human typed: \(text)"
        run(urgent: true, { c in
            let reply = try await c.chat(system: system, user: user, maxTokens: 320, temperature: 0.5, urgent: true)
            guard let obj = LLMClient.json(in: reply) as? [String: Any] else {
                // A model that ignored the format but still answered: treat it as plain talk.
                return LLMClient.line(reply, limit: 140).map { PetCommand(action: "none", say: $0) }
            }
            let minutes = (obj["minutes"] as? NSNumber)?.intValue ?? (obj["minutes"] as? String).flatMap { Int($0) }
            let value = (obj["value"] as? String) ?? (obj["value"] as? NSNumber)?.stringValue
            return PetCommand(action: ((obj["action"] as? String) ?? "none").lowercased(),
                              minutes: minutes,
                              value: value?.trimmingCharacters(in: .whitespaces),
                              say: (obj["say"] as? String).flatMap { LLMClient.line($0, limit: 140) })
        }, done: done)
    }

    // MARK: 6. Diary and memories

    private var diaryRetry = Date.distantPast

    /// Writes yesterday's diary entry if there was a yesterday worth writing about and it has none yet.
    func diaryIfDue(_ log: DailyLog = .shared) {
        guard on(.memory), !writingDiary, Date() >= diaryRetry, log.hasFreshYesterday, let y = log.yesterday,
              !memory.hasEntry(for: y.day) else { return }
        writeDiary(y)
    }

    /// Writes (or rewrites) the entry for `stats.day`, and picks up a fact or two worth remembering.
    func writeDiary(_ stats: DayStats, done: ((Bool) -> Void)? = nil) {
        guard on(.memory), !writingDiary else { done?(false); return }
        writingDiary = true
        let s = settings.species
        let happenings = memory.happenings(on: stats.day)
        let numbers = [
            "at the \(Computer.name) for \(DayStats.minutes(stats.activeSeconds))",
            "typing for \(DayStats.minutes(stats.typingSeconds))",
            "\(stats.focusSessions) focus session(s), \(stats.focusMinutes) minutes in total",
            "\(stats.breaks) break(s)",
            "\(stats.treats) treat(s), \(stats.pets) pet(s), \(stats.plays) ball game(s) for you"
        ].joined(separator: "; ")
        let system = persona(s)
        let user = """
        Write your diary entry for \(stats.day). Your human's day in numbers: \(numbers).
        Things you noticed:
        \(happenings.isEmpty ? "(nothing special)" : happenings.map { "- \($0)" }.joined(separator: "\n"))
        Write 2 or 3 short sentences in your own voice about the day you two had: what your human was up to, \
        what you did together, how you felt. Do not invent events that are not listed.
        Then, only if the day shows a lasting habit or preference of your human that is not already in the things \
        you remember, add up to 2 short facts in third person (for example "Often works past midnight"). Usually there are none.
        Reply with only JSON: {"diary": "<entry>", "facts": []}
        """
        run(urgent: true, { c -> (String, [String])? in
            let reply = try await c.chat(system: system, user: user, maxTokens: 500, temperature: 0.8)
            guard let obj = LLMClient.json(in: reply) as? [String: Any],
                  let entry = (obj["diary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  entry.count > 10 else { return nil }
            return (String(entry.prefix(600)), (obj["facts"] as? [Any] ?? []).compactMap { $0 as? String })
        }, done: { [weak self] result in
            guard let self else { return }
            self.writingDiary = false
            guard let (entry, facts) = result else {
                self.diaryRetry = Date().addingTimeInterval(1800)
                done?(false)
                return
            }
            self.memory.write(entry, for: stats.day)
            facts.prefix(2).forEach { self.memory.remember($0) }
            done?(true)
        })
    }

    // MARK: Settings page

    /// Checks the server: lists its models (choosing the first if none is set), then asks for one word.
    func test() {
        guard !testing else { return }
        testing = true
        testResult = nil
        let c = client
        Task.detached { [self] in
            let found = (try? await c.models()) ?? []
            var probe = c
            if probe.model.trimmingCharacters(in: .whitespaces).isEmpty, let first = found.first { probe.model = first }
            let outcome: String
            let ok: Bool
            do {
                let reply = try await probe.chat(system: "You are a connection test.", user: "Reply with the single word: hello",
                                                 maxTokens: 200, temperature: 0, urgent: true)
                outcome = "Connected. \(probe.model) says: \(LLMClient.line(reply, limit: 60) ?? "…")"
                ok = true
            } catch {
                outcome = error.localizedDescription
                ok = false
            }
            let model = probe.model
            await MainActor.run {
                self.models = found.sorted()
                if ok {
                    if self.settings.aiModel != model { self.settings.aiModel = model }
                    self.downUntil = .distantPast
                    self.lastError = nil
                    self.lastReply = Date()
                }
                self.testResult = (ok ? "✓ " : "✗ ") + outcome
                self.testing = false
            }
        }
    }
}
