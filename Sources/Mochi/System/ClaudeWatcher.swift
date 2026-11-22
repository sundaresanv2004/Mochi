import Foundation

/// Claude Code on this computer: whether it is working on something right now, and how much of the plan's
/// 5-hour and weekly limits is used. It only reads, and never sends Claude a prompt:
///
/// - Working: Claude Code writes each session to `~/.claude/projects/<project>/<session>.jsonl`. The tail
///   of a recently changed one says whether a turn is open (a prompt or a tool call waiting for its reply)
///   or over (a final reply, an interruption, a local command's output).
/// - Limits, from three places, the freshest winning: what Claude Code last saved in `~/.claude.json`,
///   what the Claude desktop app keeps in its usage history (macOS), and (macOS) Claude Code itself, asked
///   the way `/usage` asks: a short headless run that sends a `get_usage` control request, with no prompt,
///   no tools and no hooks, so no tokens are spent. That one runs every 5 minutes while Claude is busy and
///   every 30 otherwise, and backs off when Claude Code is missing or signed out.
final class ClaudeWatcher {
    static let shared = ClaudeWatcher()

    struct Session: Equatable {
        let id: String
        let project: String?
        let since: Date            // when the prompt that opened this turn was sent
    }

    struct Window: Equatable {
        let used: Double           // percent, 0…100
        let resetsAt: Date?
    }

    struct Usage: Equatable {
        var fiveHour: Window?
        var weekly: Window?
        let observed: Date
        let source: String         // "Claude Code", "saved by Claude Code", "Claude app"
    }

    /// What the pet sees. Updated on the main thread.
    struct Snapshot: Equatable {
        var installed = false
        var sessions: [Session] = []
        var usage: Usage?
        var lastActivity: Date?    // the last time any session's log changed
        var liveCheck = ""         // how the last live limits check went (Debug page)
    }

    private(set) var snapshot = Snapshot()
    var onChange: ((Snapshot) -> Void)?

    private let queue = DispatchQueue(label: "mochi.claude", qos: .utility)
    private var timer: DispatchSourceTimer?
    private let fm = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser

    // Confined to `queue`.
    private struct FileState {
        var modified: Date
        var size: Int
        var open: Bool
        var since: Date?
        var project: String?
    }
    private var current = Snapshot()           // the queue's own copy
    private var published = Snapshot()         // what was last handed to the main thread
    private var files: [String: FileState] = [:]
    private var candidates: [URL] = []
    private var lastListing = Date.distantPast
    private var configStamp: Date?
    private var historyStamp: Date?
    private var saved: Usage?
    private var desktop: Usage?
    private var live: Usage?
    private var organization: String?
    private var lastLive = Date.distantPast
    private var liveFailures = 0
    private var liveRunning = false
    private var wasBusy = false

    /// A turn whose log hasn't changed for this long is taken as abandoned (a killed terminal, a crash).
    static let staleAfter: TimeInterval = 20 * 60
    static let liveBusyEvery: TimeInterval = 5 * 60
    static let liveIdleEvery: TimeInterval = 30 * 60

    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 2, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.poll() }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        queue.async { self.files = [:]; self.candidates = []; self.current.sessions = [] }
    }

    // MARK: Polling (on `queue`)

    private var configFolders: [URL] {
        var folders = [home.appendingPathComponent(".claude"), home.appendingPathComponent(".config/claude")]
        if let custom = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !custom.isEmpty {
            folders.insert(URL(fileURLWithPath: custom), at: 0)
        }
        return folders
    }

    private func poll() {
        let now = Date()
        let roots = configFolders.map { $0.appendingPathComponent("projects") }.filter { fm.fileExists(atPath: $0.path) }
        var next = current
        next.installed = !roots.isEmpty || fm.fileExists(atPath: home.appendingPathComponent(".claude.json").path)

        // Which session logs changed in the last half hour: a full look every 30 s, the rest just a stat.
        if now.timeIntervalSince(lastListing) >= 30 {
            lastListing = now
            candidates = roots.flatMap { recentLogs(in: $0, since: now.addingTimeInterval(-1800)) }
            let keep = Set(candidates.map(\.path))
            files = files.filter { keep.contains($0.key) }
        }
        var newest: Date?
        for url in candidates {
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let modified = attrs[.modificationDate] as? Date else { continue }
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            newest = max(newest ?? modified, modified)
            if let known = files[url.path], known.modified == modified, known.size == size { continue }
            let previous = files[url.path]
            let tail = Self.readTail(url, size: size)
            let read = Self.turn(in: tail)
            var state = FileState(modified: modified, size: size, open: read.open ?? previous?.open ?? false,
                                  since: nil, project: read.project ?? previous?.project)
            if state.open {
                // A turn already being followed keeps its start (its prompt may have scrolled out of the
                // tail); a newer prompt means a new turn began between two looks.
                if previous?.open == true, let p = previous?.since {
                    state.since = read.since.map { max($0, p) } ?? p
                } else {
                    state.since = read.since ?? modified
                }
            }
            files[url.path] = state
        }
        next.lastActivity = newest.map { max($0, current.lastActivity ?? $0) } ?? current.lastActivity
        next.sessions = files.compactMap { path, f -> Session? in
            guard f.open, now.timeIntervalSince(f.modified) < Self.staleAfter else { return nil }
            let id = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return Session(id: id, project: f.project, since: f.since ?? f.modified)
        }.sorted { $0.since < $1.since }

        readSavedUsage()
        let busy = !next.sessions.isEmpty
        let recentlyActive = next.lastActivity.map { now.timeIntervalSince($0) < 600 } ?? false
        maybeCheckLive(now, busy: busy || recentlyActive, turnEnded: wasBusy && !busy)
        wasBusy = busy
        next.usage = Self.merge([live, saved, desktop].compactMap { $0 }, now: now)

        current = next
        guard next != published else { return }
        published = next
        DispatchQueue.main.async {
            self.snapshot = next
            self.onChange?(next)
        }
    }

    private func recentLogs(in root: URL, since: Date) -> [URL] {
        guard let projects = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        var result: [URL] = []
        for folder in projects {
            // Only the sessions themselves: subagents keep their own logs in a folder below.
            guard let logs = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for log in logs where log.pathExtension == "jsonl" {
                let modified = (try? log.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let modified, modified >= since { result.append(log) }
            }
        }
        return result
    }

    /// The last 256 KB of a log, from the first whole line.
    static func readTail(_ url: URL, size: Int, limit: Int = 256 << 10) -> [Substring] {
        guard let h = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? h.close() }
        let offset = max(0, size - limit)
        try? h.seek(toOffset: UInt64(offset))
        guard let data = try? h.readToEnd(), let text = String(data: data, encoding: .utf8)
                ?? String(data: data.dropFirst(min(3, data.count)), encoding: .utf8) else { return [] }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        if offset > 0, !lines.isEmpty { lines.removeFirst() }      // cut in the middle
        return lines
    }

    // MARK: Reading a session log

    struct TurnRead: Equatable {
        var open: Bool?            // nil: nothing in the tail says either way
        var since: Date?           // when the open turn's prompt was sent, if it's in the tail
        var project: String?
    }

    private static let endings: Set<String> = ["end_turn", "stop_sequence", "max_tokens", "refusal", "pause_turn"]

    /// Whether the newest exchange in these log lines leaves a turn open, and since when.
    static func turn(in lines: [Substring]) -> TurnRead {
        var read = TurnRead()
        var openAt: Int?
        for i in lines.indices.reversed() {
            let line = lines[i]
            // Cheap filters first: tool results and request copies can be large.
            guard line.contains("\"type\":\"user\"") || line.contains("\"type\":\"assistant\"") else { continue }
            guard let json = object(line), let type = json["type"] as? String, type == "user" || type == "assistant" else { continue }
            if read.project == nil, let cwd = json["cwd"] as? String, !cwd.isEmpty {
                read.project = URL(fileURLWithPath: cwd).lastPathComponent
            }
            if json["isSidechain"] as? Bool == true || json["isMeta"] as? Bool == true { continue }
            if type == "assistant" {
                let message = json["message"] as? [String: Any] ?? [:]
                let stop = message["stop_reason"] as? String
                let failed = json["isApiErrorMessage"] as? Bool == true
                if (stop.map(endings.contains) ?? false) || failed { read.open = false; return read }
                read.open = true; openAt = i; break
            }
            if json["toolEndsTurn"] as? Bool == true { read.open = false; return read }
            let texts = Self.texts(json)
            if texts.contains(where: { $0.hasPrefix("[Request interrupted by user") }) { read.open = false; return read }
            if texts.contains(where: isLocalOutput) { read.open = false; return read }
            read.open = true; openAt = i; break
        }
        guard read.open == true, let from = openAt else { return read }
        // Back to the prompt that opened it: the person's own words, not a tool's result.
        for i in lines[...from].indices.reversed() {
            let line = lines[i]
            guard line.contains("\"type\":\"user\"") || line.contains("\"type\":\"assistant\"") else { continue }
            guard let json = object(line), let type = json["type"] as? String else { continue }
            if read.project == nil, let cwd = json["cwd"] as? String, !cwd.isEmpty {
                read.project = URL(fileURLWithPath: cwd).lastPathComponent
            }
            if json["isSidechain"] as? Bool == true || json["isMeta"] as? Bool == true { continue }
            if type == "assistant" {
                let stop = (json["message"] as? [String: Any])?["stop_reason"] as? String
                if stop.map(endings.contains) ?? false { break }        // the previous turn: its prompt is after this
                continue
            }
            guard type == "user", !isToolResult(json) else { continue }
            let texts = Self.texts(json)
            if texts.contains(where: isLocalOutput) { break }
            read.since = timestamp(json["timestamp"])
            break
        }
        return read
    }

    private static func object(_ line: Substring) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
    }

    private static func texts(_ json: [String: Any]) -> [String] {
        let content = (json["message"] as? [String: Any])?["content"]
        if let text = content as? String { return [text] }
        return (content as? [[String: Any]] ?? []).compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
    }

    private static func isToolResult(_ json: [String: Any]) -> Bool {
        let content = (json["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
        return content.contains { $0["type"] as? String == "tool_result" }
    }

    private static func isLocalOutput(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("<local-command-stdout>") || t.hasPrefix("<local-command-stderr>")
    }

    static func timestamp(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: text) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: text) { return d }
        // "2026-11-23T15:00:00.574281+00:00": more fractional digits than the formatter takes.
        if let dot = text.firstIndex(of: "."), let zone = text[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let trimmed = String(text[..<dot]) + String(text[zone...])
            return f.date(from: trimmed)
        }
        return nil
    }

    // MARK: Limits

    /// One window as Claude reports it: `{"utilization": 19, "resets_at": "…"}`.
    static func window(_ value: Any?) -> Window? {
        guard let w = value as? [String: Any], let n = w["utilization"] as? NSNumber, n.doubleValue.isFinite else { return nil }
        return Window(used: min(100, max(0, n.doubleValue)), resetsAt: timestamp(w["resets_at"]))
    }

    static func usage(fromLimits limits: [String: Any], observed: Date, source: String) -> Usage? {
        let u = Usage(fiveHour: window(limits["five_hour"]), weekly: window(limits["seven_day"]), observed: observed, source: source)
        return u.fiveHour == nil && u.weekly == nil ? nil : u
    }

    /// The freshest reading of each window, without one that has renewed since it was read. A reset time
    /// another reading knows fills in for a reading that has none (the desktop app keeps only percentages).
    static func merge(_ readings: [Usage], now: Date) -> Usage? {
        let sorted = readings.sorted { $0.observed > $1.observed }
        guard let freshest = sorted.first else { return nil }
        func pick(_ get: (Usage) -> Window?, length: TimeInterval) -> Window? {
            for r in sorted {
                guard let w = get(r) else { continue }
                let resets = w.resetsAt ?? sorted.compactMap({ get($0)?.resetsAt }).first { $0 > r.observed }
                if let resets, resets <= now { continue }                       // renewed since this reading
                if resets == nil, now.timeIntervalSince(r.observed) >= length { continue }
                return Window(used: w.used, resetsAt: resets)
            }
            return nil
        }
        let merged = Usage(fiveHour: pick({ $0.fiveHour }, length: 5 * 3600), weekly: pick({ $0.weekly }, length: 86_400),
                           observed: freshest.observed, source: freshest.source)
        return merged.fiveHour == nil && merged.weekly == nil ? nil : merged
    }

    /// What Claude Code and the desktop app last saved: read again only when their files change.
    private func readSavedUsage() {
        let config = home.appendingPathComponent(".claude.json")
        let stamp = (try? fm.attributesOfItem(atPath: config.path))?[.modificationDate] as? Date
        if stamp != configStamp {
            configStamp = stamp
            if let data = try? Data(contentsOf: config), data.count < 32 << 20,
               let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                organization = (json["oauthAccount"] as? [String: Any])?["organizationUuid"] as? String
                if let cached = json["cachedUsageUtilization"] as? [String: Any],
                   let ms = (cached["fetchedAtMs"] as? NSNumber)?.doubleValue,
                   let limits = cached["utilization"] as? [String: Any] {
                    saved = Self.usage(fromLimits: limits, observed: Date(timeIntervalSince1970: ms / 1000), source: "saved by Claude Code")
                }
            }
        }
        #if os(macOS)
        let history = home.appendingPathComponent("Library/Application Support/Claude/plan-usage-history.json")
        let hstamp = (try? fm.attributesOfItem(atPath: history.path))?[.modificationDate] as? Date
        guard hstamp != historyStamp else { return }
        historyStamp = hstamp
        desktop = (try? Data(contentsOf: history)).flatMap { Self.desktopUsage($0, organization: organization) }
        #endif
    }

    /// The newest sample in the desktop app's history (`{"t": ms, "org": "…", "u": {"fh": 15, "sd": 43}}`),
    /// for the same account as Claude Code when that is known.
    static func desktopUsage(_ data: Data, organization: String?) -> Usage? {
        guard data.count < 8 << 20, let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let version = (json["version"] as? NSNumber)?.intValue, version == 1 || version == 2,
              let samples = json["samples"] as? [[String: Any]] else { return nil }
        let mine = samples.filter { s in organization == nil || (s["org"] as? String).map { $0 == organization } ?? true }
        guard let last = mine.max(by: { (($0["t"] as? NSNumber)?.doubleValue ?? 0) < (($1["t"] as? NSNumber)?.doubleValue ?? 0) }),
              let ms = (last["t"] as? NSNumber)?.doubleValue else { return nil }
        let values = version == 1 ? last : (last["u"] as? [String: Any] ?? [:])
        func w(_ key: String) -> Window? {
            guard let n = values[key] as? NSNumber, n.doubleValue.isFinite else { return nil }
            return Window(used: min(100, max(0, n.doubleValue)), resetsAt: nil)
        }
        let u = Usage(fiveHour: w("fh"), weekly: w("sd"), observed: Date(timeIntervalSince1970: ms / 1000), source: "Claude app")
        return u.fiveHour == nil && u.weekly == nil ? nil : u
    }

    // MARK: Asking Claude Code (macOS)

    private func maybeCheckLive(_ now: Date, busy: Bool, turnEnded: Bool) {
        #if os(macOS)
        guard !liveRunning, current.installed || fm.fileExists(atPath: home.appendingPathComponent(".claude.json").path) else { return }
        let since = now.timeIntervalSince(lastLive)
        let every: TimeInterval = liveFailures > 0 ? min(1800, 300 * pow(2, Double(liveFailures - 1)))
            : (busy ? Self.liveBusyEvery : Self.liveIdleEvery)
        // A turn that just ended is the moment usage went up: look a minute later at the soonest.
        guard since >= every || (turnEnded && liveFailures == 0 && since >= 60) else { return }
        lastLive = now
        liveRunning = true
        DispatchQueue.global(qos: .utility).async {
            let result = Self.askClaude(home: self.home)
            self.queue.async {
                self.liveRunning = false
                let status: String
                switch result {
                case .success(let usage):
                    self.live = usage
                    self.liveFailures = 0
                    status = "OK at \(Self.clock(usage.observed))"
                case .failure(let why):
                    self.liveFailures += 1
                    status = "\(why) (\(self.liveFailures)× in a row)"
                }
                self.current.liveCheck = status       // handed over with the next look
            }
        }
        #endif
    }

    static func clock(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }

    #if os(macOS)
    enum LiveFailure: String, Error { case missing = "Claude Code not found", signedOut = "not signed in",
                                      outdated = "Claude Code too old", unreachable = "no answer" }

    /// Where Claude Code gets installed: its own installer, Homebrew, npm, and the Node version managers.
    static func executable(home: URL) -> URL? {
        let h = home.path
        var folders = ["\(h)/.local/bin", "\(h)/.claude/local", "/opt/homebrew/bin", "/usr/local/bin",
                       "\(h)/.volta/bin", "\(h)/.bun/bin", "\(h)/.npm-global/bin", "\(h)/Library/pnpm"]
        folders += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        folders += nodeFolders(home: home)
        return folders.lazy.map { URL(fileURLWithPath: $0).appendingPathComponent("claude") }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// The newest Node of each version manager, for a Claude Code installed with npm.
    static func nodeFolders(home: URL) -> [String] {
        let h = home.path
        func newest(_ dir: String, suffix: String) -> [String] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
            return names.sorted { $0.compare($1, options: .numeric) == .orderedDescending }.map { "\(dir)/\($0)\(suffix)" }
        }
        return newest("\(h)/.nvm/versions/node", suffix: "/bin") + newest("\(h)/.asdf/installs/nodejs", suffix: "/bin")
            + newest("\(h)/.local/share/mise/installs/node", suffix: "/bin")
            + newest("\(h)/Library/Application Support/fnm/node-versions", suffix: "/installation/bin")
    }

    /// One headless run of Claude Code that answers what `/usage` shows. No prompt, tools, MCP servers,
    /// hooks or saved session; it signs in (and refreshes its sign-in) by itself.
    static func askClaude(home: URL, timeout: TimeInterval = 20) -> Result<Usage, LiveFailure> {
        guard let exe = executable(home: home) else { return .failure(.missing) }
        let p = Process()
        p.executableURL = exe
        p.arguments = ["--print", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
                       "--no-session-persistence", "--tools", "", "--strict-mcp-config", "--mcp-config", "{\"mcpServers\":{}}",
                       "--setting-sources", "", "--settings", "{\"disableAllHooks\":true}"]
        // Mochi may itself have been started from a Claude session: its tokens and routing must not leak in.
        var env = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("CLAUDE") && !$0.key.hasPrefix("ANTHROPIC_") }
        env["DISABLE_AUTOUPDATER"] = "1"
        env["PATH"] = ([exe.deletingLastPathComponent().path, env["PATH"] ?? "/usr/bin:/bin"] + nodeFolders(home: home)).joined(separator: ":")
        p.environment = env
        p.currentDirectoryURL = FileManager.default.temporaryDirectory
        let input = Pipe(), output = Pipe()
        p.standardInput = input
        p.standardOutput = output
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return .failure(.missing) }

        let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
        defer {
            killer.cancel()
            try? input.fileHandleForWriting.close()
            if p.isRunning { p.terminate() }
        }
        func send(_ id: String, _ request: [String: Any]) {
            let message: [String: Any] = ["type": "control_request", "request_id": id, "request": request]
            guard var data = try? JSONSerialization.data(withJSONObject: message) else { return }
            data.append(0x0A)
            try? input.fileHandleForWriting.write(contentsOf: data)
        }
        send("init", ["subtype": "initialize"])
        send("usage", ["subtype": "get_usage", "skip_behaviors": true])

        var buffer = Data()
        let reader = output.fileHandleForReading
        while true {
            let chunk = reader.availableData
            if chunk.isEmpty { return .failure(.unreachable) }            // exited (or was stopped by the timeout)
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<nl]
                buffer.removeSubrange(buffer.startIndex...nl)
                guard let json = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                      json["type"] as? String == "control_response",
                      let response = json["response"] as? [String: Any], response["request_id"] as? String == "usage" else { continue }
                guard response["subtype"] as? String == "success" else {
                    let error = (response["error"] as? String ?? "").lowercased()
                    if error.contains("supported") || error.contains("unknown") { return .failure(.outdated) }
                    if error.contains("auth") || error.contains("login") || error.contains("sign") { return .failure(.signedOut) }
                    return .failure(.unreachable)
                }
                let result = response["response"] as? [String: Any] ?? [:]
                guard result["rate_limits_available"] as? Bool == true, let limits = result["rate_limits"] as? [String: Any] else {
                    return .failure(.signedOut)
                }
                guard let usage = usage(fromLimits: limits, observed: Date(), source: "Claude Code") else { return .failure(.unreachable) }
                return .success(usage)
            }
        }
    }
    #endif
}

/// Says when a limit crosses the next 10%: 10, 20 … 100. Remembered between launches, so a restart doesn't
/// repeat itself, and started over when the window renews.
struct ClaudeLimitAlerts {
    struct Mark: Equatable { var step: Int; var resets: Double? }   // resets: minutes since 1970, rounded
    var marks: [String: Mark] = [:]

    /// The 10% step to warn about now, if this reading crossed one.
    mutating func update(_ key: String, _ window: ClaudeWatcher.Window) -> Int? {
        let step = min(10, Int(window.used / 10))
        // Claude reports the same reset a few microseconds apart from one reading to the next.
        let resets = window.resetsAt.map { ($0.timeIntervalSince1970 / 60).rounded() }
        guard var mark = marks[key] else {
            marks[key] = Mark(step: step, resets: resets)      // first sight: just note where it stands
            return nil
        }
        if let resets, let old = mark.resets, abs(resets - old) > 5 {
            mark = Mark(step: 0, resets: resets)                // a new window
        } else if step < mark.step {
            mark.step = step                                    // renewed without our knowing when
        }
        if let resets { mark.resets = resets }
        defer { marks[key] = mark }
        guard step > mark.step else { return nil }
        mark.step = step
        return step
    }

    // Saved in UserDefaults as ["five_hour": [step, resets]].
    static let key = "claude.limitMarks"

    static func load(_ d: UserDefaults = .standard) -> ClaudeLimitAlerts {
        var a = ClaudeLimitAlerts()
        for (k, v) in d.dictionary(forKey: key) as? [String: [Double]] ?? [:] where !v.isEmpty {
            a.marks[k] = Mark(step: Int(v[0]), resets: v.count > 1 && v[1] > 0 ? v[1] : nil)
        }
        return a
    }

    func save(_ d: UserDefaults = .standard) {
        d.set(marks.mapValues { [Double($0.step), $0.resets ?? 0] }, forKey: Self.key)
    }
}
