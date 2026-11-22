#if os(Windows)
import Foundation
import WinSDK
import AppKitLite

/// The Windows settings window: a page served by Mochi itself on 127.0.0.1 and opened in your browser.
/// It only listens on the loopback address, every request must carry a random token that changes each
/// launch, and requests naming any other host are refused, so other web pages can't reach it.
final class SettingsServer {
    static let shared = SettingsServer()

    /// What the page's buttons do that settings alone can't (handled by the app).
    var onAction: ((String, [String: Any]) -> Void)?

    private let token: String = {
        var rng = SystemRandomNumberGenerator()
        return (0..<32).map { _ in String("abcdefghijklmnopqrstuvwxyz0123456789".randomElement(using: &rng)!) }.joined()
    }()
    private var port: UInt16 = 0
    private var listener = SOCKET(bitPattern: -1)
    private var previews: [String: Data] = [:]

    /// Starts the server if needed and opens the page (on `page`, e.g. "ai").
    func open(page: String = "pet") {
        guard start() else { return }
        NSWorkspace.shared.open(URL(string: "http://127.0.0.1:\(port)/?t=\(token)#\(page)")!)
    }

    private func start() -> Bool {
        if listener != SOCKET(bitPattern: -1) { return true }
        var data = WSADATA()
        _ = WSAStartup(0x0202, &data)
        let s = socket(AF_INET, Int32(SOCK_STREAM), Int32(IPPROTO_TCP.rawValue))
        guard s != SOCKET(bitPattern: -1) else { return false }
        var addr = sockaddr_in()
        addr.sin_family = ADDRESS_FAMILY(AF_INET)
        addr.sin_addr.S_un.S_addr = UInt32(0x7f00_0001).bigEndian
        let len = Int32(MemoryLayout<sockaddr_in>.size)
        let ok = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, len) } } == 0
        guard ok, listen(s, 16) == 0 else { closesocket(s); return false }
        var got = sockaddr_in()
        var gotLen = len
        _ = withUnsafeMutablePointer(to: &got) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(s, $0, &gotLen) } }
        port = UInt16(bigEndian: got.sin_port)
        listener = s
        Thread { [weak self] in self?.serve(s) }.start()
        return true
    }

    // MARK: HTTP

    private func serve(_ s: SOCKET) {
        while true {
            let conn = accept(s, nil, nil)
            if conn == SOCKET(bitPattern: -1) { return }
            Thread { [weak self] in self?.handle(conn) }.start()
        }
    }

    private func readRequest(_ conn: SOCKET) -> (head: String, body: Data)? {
        var buf = Data()
        var chunk = [CChar](repeating: 0, count: 8192)
        while buf.count < 2_000_000 {
            let n = chunk.withUnsafeMutableBufferPointer { recv(conn, $0.baseAddress, Int32($0.count), 0) }
            if n <= 0 { break }
            buf.append(contentsOf: chunk[0..<Int(n)].map { UInt8(bitPattern: $0) })
            if let end = buf.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: buf[..<end.lowerBound], as: UTF8.self)
                let length = head.split(separator: "\r\n").first { $0.lowercased().hasPrefix("content-length:") }
                    .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
                if buf.count - end.upperBound >= length {
                    return (head, buf[end.upperBound..<(end.upperBound + length)])
                }
            }
        }
        return nil
    }

    private func respond(_ conn: SOCKET, _ status: String, _ type: String, _ body: Data) {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        let out = Data(head.utf8) + body
        _ = out.withUnsafeBytes { $0.withMemoryRebound(to: CChar.self) { send(conn, $0.baseAddress, Int32($0.count), 0) } }
        closesocket(conn)
    }

    private func handle(_ conn: SOCKET) {
        guard let (head, body) = readRequest(conn) else { closesocket(conn); return }
        let lines = head.split(separator: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        guard parts.count >= 2 else { closesocket(conn); return }
        let method = String(parts[0]), target = String(parts[1])
        let host = lines.first { $0.lowercased().hasPrefix("host:") }.map { $0.dropFirst(5).trimmingCharacters(in: .whitespaces) } ?? ""
        let comps = URLComponents(string: "http://127.0.0.1\(target)")
        var query: [String: String] = [:]
        for i in comps?.queryItems ?? [] { query[i.name] = i.value ?? "" }
        // Only this page, opened by Mochi, on this exact address.
        guard host == "127.0.0.1:\(port)", query["t"] == token else {
            respond(conn, "403 Forbidden", "text/plain", Data("Forbidden".utf8)); return
        }
        let path = comps?.path ?? "/"
        switch (method, path) {
        case ("GET", "/"):
            respond(conn, "200 OK", "text/html; charset=utf-8", Data(SettingsPage.html.utf8))
        case ("GET", "/api/state"):
            let json = DispatchQueue.main.sync { SettingsState.snapshot() }
            respond(conn, "200 OK", "application/json", json)
        case ("GET", "/pet.png"):
            let key = "\(query["species"] ?? "")|\(query["outfit"] ?? "")|\(query["mood"] ?? "")"
            let png = DispatchQueue.main.sync { preview(key, query) }
            respond(conn, "200 OK", "image/png", png)
        case ("POST", "/api/set"), ("POST", "/api/do"):
            let obj = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
            DispatchQueue.main.sync {
                if path == "/api/set", let key = obj["key"] as? String { SettingsState.set(key, obj["value"]) }
                if path == "/api/do", let name = obj["action"] as? String { self.onAction?(name, obj) }
            }
            respond(conn, "200 OK", "application/json", DispatchQueue.main.sync { SettingsState.snapshot() })
        default:
            respond(conn, "404 Not Found", "text/plain", Data("Not found".utf8))
        }
    }

    /// A picture of a pet, for the page (cached).
    private func preview(_ key: String, _ q: [String: String]) -> Data {
        if let d = previews[key] { return d }
        let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
        v.species = Species(rawValue: q["species"] ?? "") ?? .mochi
        v.outfit = Outfit(rawValue: q["outfit"] ?? "") ?? Outfit.none
        v.time = 0.6
        if q["mood"] == "happy" { v.mood = .happy }
        guard let canvas = ImageCanvas(size: PetView.size, scale: 2) else { return Data() }
        canvas.draw { v.draw(v.bounds) }
        let file = NSTemporaryDirectory() + "mochi-preview-\(ProcessInfo.processInfo.processIdentifier).png"
        guard canvas.writePNG(to: file), let d = FileManager.default.contents(atPath: file) else { return Data() }
        try? FileManager.default.removeItem(atPath: file)
        previews[key] = d
        return d
    }
}

/// What the page shows and changes, as JSON.
enum SettingsState {
    static func snapshot() -> Data {
        let s = PetSettings.shared, mind = PetMind.shared, ai = PetAI.shared, memory = PetMemory.shared
        let google = GoogleCalendar.shared, debug = PetDebug.shared, log = DailyLog.shared
        func day(_ d: DayStats?) -> Any {
            guard let d else { return NSNull() }
            return ["day": d.day, "active": DayStats.minutes(d.activeSeconds), "typing": DayStats.minutes(d.typingSeconds),
                    "focusSessions": d.focusSessions, "focusMinutes": d.focusMinutes, "breaks": d.breaks,
                    "treats": d.treats, "pets": d.pets, "plays": d.plays,
                    "summary": d.summary(prefix: d.day == log.today.day ? "Today" : (log.hasFreshYesterday ? "Yesterday" : d.day))]
        }
        let df = DateFormatter()
        df.dateFormat = "EEE HH:mm"
        let upNext: [[String: Any]] = google.upNext.prefix(4).map { e in
            ["title": e.title, "when": e.allDay ? "All day" : df.string(from: e.start),
             "reminders": e.reminders.map { Dialogue.inTime($0) + " before" }.joined(separator: ", ")]
        }
        let googleStatus: String
        switch google.status {
        case .signedOut: googleStatus = "signedOut"
        case .signingIn: googleStatus = "signingIn"
        case .signedIn: googleStatus = "signedIn"
        }
        let state: [String: Any] = [
            "settings": [
                "species": s.species.rawValue, "petSize": s.petSize.rawValue, "chattiness": s.chattiness.rawValue,
                "walkOnWindows": s.walkOnWindows, "climbEdges": s.climbEdges, "followCursor": s.followCursor,
                "reactToMedia": s.reactToMedia, "reactToTyping": s.reactToTyping, "secondPet": s.secondPet,
                "companionSpecies": s.companionSpecies.rawValue, "outfit": s.outfit.rawValue, "dailyCheckIn": s.dailyCheckIn,
                "googleCalendarAlerts": s.googleCalendarAlerts, "googleAlertAtStart": s.googleAlertAtStart,
                "googleClientID": s.googleClientID, "reminderMinutes": s.reminderMinutes,
                "breakReminders": s.breakReminders, "breakMinutes": s.breakMinutes, "quietOnCalls": s.quietOnCalls,
                "reactToOtherAudio": s.reactToOtherAudio, "systemAware": s.systemAware, "aiEnabled": s.aiEnabled,
                "aiBaseURL": s.aiBaseURL, "aiModel": s.aiModel, "aiHasKey": !s.aiKey.isEmpty, "aiDialogue": s.aiDialogue,
                "aiReactions": s.aiReactions, "aiBrain": s.aiBrain, "aiBanter": s.aiBanter, "aiMemory": s.aiMemory,
                "aiCommands": s.aiCommands, "launchAtLogin": LoginItem.enabled, "launchAtLoginAvailable": LoginItem.available
            ],
            "species": Species.allCases.map { ["id": $0.rawValue, "name": $0.name, "tagline": $0.tagline,
                                               "style": $0.style == .cute ? "cute" : "tough"] },
            "outfits": Outfit.unlocked(at: mind.level).map { ["id": $0.rawValue, "label": $0.label] },
            "nextOutfit": Outfit.next(after: mind.level).map { "\($0.label) unlocks at level \($0.unlockLevel)" } ?? "",
            "sizes": PetSize.allCases.map { ["id": $0.rawValue, "label": $0.label] },
            "chattiness": Chattiness.allCases.map { ["id": $0.rawValue, "label": $0.label] },
            "reminders": ReminderKind.allCases.map { ["id": $0.rawValue, "label": $0.label, "default": $0.defaultMinutes] },
            "intervals": ReminderKind.intervals,
            "mind": ["feeling": mind.feeling.label, "energy": mind.energy, "fullness": mind.fullness, "joy": mind.joy,
                     "bond": mind.levelProgress, "bondTitle": mind.bondTitle, "level": mind.level, "days": mind.daysTogether],
            "today": day(log.today), "yesterday": day(log.yesterday), "hasFreshYesterday": log.hasFreshYesterday,
            "ai": ["ready": ai.ready, "testing": ai.testing, "testResult": ai.testResult ?? "", "lastError": ai.lastError ?? "",
                   "models": ai.models, "lines": ai.generatedLineCount, "writingDiary": ai.writingDiary],
            "memory": ["facts": memory.facts, "diary": memory.diary.prefix(7).map { ["day": $0.day, "text": $0.text] }],
            "google": ["status": googleStatus, "email": google.email, "problem": google.problem ?? "",
                       "hasClient": google.hasClient, "syncing": google.syncing,
                       "lastSync": google.lastSync.map { df.string(from: $0) } ?? "", "events": google.events.count,
                       "upNext": upNext],
            "debug": ["petState": debug.petState, "reminders": debug.reminders, "reminderState": debug.reminderState,
                      "presence": debug.presence, "sound": debug.sound, "soundApps": debug.soundApps,
                      "screens": debug.screens, "pets": debug.pets,
                      "social": SocialKind.allCases.map { ["id": "\($0)", "label": $0.label] }]
        ]
        return (try? JSONSerialization.data(withJSONObject: state)) ?? Data("{}".utf8)
    }

    /// Changes one setting from the page.
    static func set(_ key: String, _ value: Any?) {
        let s = PetSettings.shared
        let b = value as? Bool ?? false
        let str = value as? String ?? ""
        let num = (value as? NSNumber)?.intValue ?? Int(str) ?? 0
        switch key {
        case "species": if let v = Species(rawValue: str) { s.species = v }
        case "companionSpecies": if let v = Species(rawValue: str) { s.companionSpecies = v }
        case "petSize": if let v = PetSize(rawValue: str) { s.petSize = v }
        case "chattiness": if let v = Chattiness(rawValue: str) { s.chattiness = v }
        case "outfit": if let v = Outfit(rawValue: str) { s.outfit = v }
        case "walkOnWindows": s.walkOnWindows = b
        case "climbEdges": s.climbEdges = b
        case "followCursor": s.followCursor = b
        case "reactToMedia": s.reactToMedia = b
        case "reactToTyping": s.reactToTyping = b
        case "secondPet": s.secondPet = b
        case "dailyCheckIn": s.dailyCheckIn = b
        case "googleCalendarAlerts": s.googleCalendarAlerts = b
        case "googleAlertAtStart": s.googleAlertAtStart = b
        case "googleClientID": s.googleClientID = str.trimmingCharacters(in: .whitespacesAndNewlines)
        case "googleClientSecret": GoogleCalendar.shared.setClientSecret(str)
        case "breakReminders": s.breakReminders = b
        case "breakMinutes": s.breakMinutes = max(10, num)
        case "quietOnCalls": s.quietOnCalls = b
        case "reactToOtherAudio": s.reactToOtherAudio = b
        case "systemAware": s.systemAware = b
        case "aiEnabled": s.aiEnabled = b
        case "aiBaseURL": s.aiBaseURL = str.trimmingCharacters(in: .whitespacesAndNewlines)
        case "aiModel": s.aiModel = str.trimmingCharacters(in: .whitespacesAndNewlines)
        case "aiKey": s.aiKey = str.trimmingCharacters(in: .whitespacesAndNewlines)
        case "aiDialogue": s.aiDialogue = b
        case "aiReactions": s.aiReactions = b
        case "aiBrain": s.aiBrain = b
        case "aiBanter": s.aiBanter = b
        case "aiMemory": s.aiMemory = b
        case "aiCommands": s.aiCommands = b
        case "launchAtLogin": s.launchAtLogin = LoginItem.set(b)
        default:
            // "reminder.water" = minutes (0 = off)
            if key.hasPrefix("reminder."), let kind = ReminderKind(rawValue: String(key.dropFirst(9))) {
                s.reminderMinutes[kind.rawValue] = num
            }
        }
    }
}
#endif
