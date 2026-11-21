import AppKit
import CryptoKit
import Foundation
import Network

/// Google Calendar: sign in once in Settings › Reminders, and the pet reads out each event's own
/// notifications ("30 minutes before", "5 minutes before"…) when they fall due, just like Google would.
///
/// Read-only access. Mochi talks to Google directly from this Mac, keeps the sign-in in the keychain,
/// and only ever looks at each event's title, start time and notification times. Event titles appear in
/// the pet's bubble and nowhere else (they are never sent to the AI server).

// MARK: - Events and reminders

/// One upcoming event, reduced to what the pet needs.
struct CalendarEvent: Equatable, Identifiable {
    let id: String
    let title: String
    let start: Date
    let allDay: Bool
    /// Minutes before the start that the event's notifications are set for, largest first.
    let reminders: [Int]
}

/// One thing for the pet to say: "Standup in 5 min".
struct CalendarAlarm: Equatable {
    let eventID: String
    let title: String
    let start: Date
    let minutes: Int            // how long before the start; 0 = as it starts
    var id: String { "\(eventID)@\(Int(start.timeIntervalSince1970))-\(minutes)" }
    var fireAt: Date { start.addingTimeInterval(TimeInterval(-minutes * 60)) }

    /// Minutes actually left at `now`, which is what the pet says (it can differ from `minutes` when the
    /// Mac was asleep at the exact moment and the reminder is caught up a little late).
    func minutesLeft(_ now: Date) -> Int { max(0, Int((start.timeIntervalSince(now) / 60).rounded())) }
}

/// The bits of Google's JSON that Mochi reads.
struct GoogleReminder: Decodable { let method: String?; let minutes: Int }

struct GoogleCalendarEntry: Decodable {
    let id: String
    let summary: String?
    let selected: Bool?
    let primary: Bool?
    let defaultReminders: [GoogleReminder]?
}

struct GoogleEvent: Decodable {
    struct When: Decodable { let dateTime: String?; let date: String? }
    struct Reminders: Decodable { let useDefault: Bool?; let overrides: [GoogleReminder]? }
    struct Attendee: Decodable {
        let isSelf: Bool?
        let responseStatus: String?
        enum CodingKeys: String, CodingKey { case isSelf = "self", responseStatus }
    }
    let id: String
    let status: String?
    let summary: String?
    let start: When?
    let reminders: Reminders?
    let attendees: [Attendee]?
    let eventType: String?
}

extension GoogleEvent {
    /// The event as the pet sees it, or nil for things it should never remind you about:
    /// cancelled events, ones you declined, and working-location markers.
    func reduced(calendarDefaults: [GoogleReminder]) -> CalendarEvent? {
        if status == "cancelled" || eventType == "workingLocation" { return nil }
        if attendees?.contains(where: { $0.isSelf == true && $0.responseStatus == "declined" }) == true { return nil }
        let allDay: Bool
        let date: Date
        if let s = start?.dateTime, let d = GoogleTime.parse(s) { date = d; allDay = false }
        else if let s = start?.date, let d = GoogleTime.parseDay(s) { date = d; allDay = true }
        else { return nil }

        // Google's rule: an event either uses its calendar's default notifications or lists its own.
        // The calendar defaults are for timed events only (all-day defaults aren't available to apps).
        let list: [GoogleReminder]
        if reminders?.useDefault ?? true { list = allDay ? [] : calendarDefaults }
        else { list = reminders?.overrides ?? [] }
        let minutes = Array(Set(list.map(\.minutes).filter { $0 >= 0 })).sorted(by: >)

        let name = (summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return CalendarEvent(id: id, title: String((name.isEmpty ? "An event" : name).prefix(40)),
                             start: date, allDay: allDay, reminders: minutes)
    }
}

extension CalendarEvent {
    /// When the pet should speak up: at each of the event's notification times, and as it starts if asked.
    func alarms(atStart: Bool) -> [CalendarAlarm] {
        var minutes = reminders
        if atStart, !allDay, !minutes.contains(0) { minutes.append(0) }
        return minutes.map { CalendarAlarm(eventID: id, title: title, start: start, minutes: $0) }
    }
}

enum GoogleTime {
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parse(_ s: String) -> Date? { plain.date(from: s) ?? fractional.date(from: s) }
    /// All-day events start at local midnight on their date.
    static func parseDay(_ s: String) -> Date? { day.timeZone = .current; return day.date(from: s) }
    static func format(_ d: Date) -> String { plain.string(from: d) }
}

/// Picks which reminders to say right now. Each fires once; one missed while the Mac slept is caught up
/// as long as the event hasn't started yet (only the latest missed one per event, so no pile-up).
struct AlarmSchedule {
    private(set) var announced = Set<String>()

    mutating func due(_ alarms: [CalendarAlarm], now: Date) -> [CalendarAlarm] {
        var out: [CalendarAlarm] = []
        let byEvent = Dictionary(grouping: alarms) { "\($0.eventID)@\(Int($0.start.timeIntervalSince1970))" }
        for (_, list) in byEvent {
            let passed = list.filter { $0.fireAt <= now }.sorted { $0.fireAt < $1.fireAt }
            guard let latest = passed.last else { continue }
            // "Starting now" stays relevant for a minute; anything earlier until the event starts.
            let fresh = latest.minutes == 0 ? now.timeIntervalSince(latest.start) < 60 : latest.start > now
            let isNew = !announced.contains(latest.id)
            passed.forEach { announced.insert($0.id) }
            if fresh, isNew { out.append(latest) }
        }
        if announced.count > 2000 { announced.removeAll(); alarms.filter { $0.fireAt <= now }.forEach { announced.insert($0.id) } }
        return out.sorted { $0.start < $1.start }
    }
}

// MARK: - Signing in (OAuth for installed apps, with PKCE and a loopback redirect)

struct GoogleError: LocalizedError {
    let message: String
    var signedOut = false           // the sign-in was revoked or expired: you have to sign in again
    var errorDescription: String? { message }
}

enum GoogleOAuth {
    static let scope = "https://www.googleapis.com/auth/calendar.readonly openid email"

    struct Tokens {
        var access: String
        var expires: Date
        var refresh: String?
        var email: String?
    }

    /// Opens Google's sign-in page in the browser and waits for it to come back to Mochi.
    static func signIn(clientID: String, secret: String, receiver: LoopbackReceiver) async throws -> Tokens {
        let verifier = randomString(64)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let state = randomString(24)
        let port = try await receiver.start()
        let redirect = "http://127.0.0.1:\(port)"

        var c = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        c.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent")
        ]
        let page = c.url!
        await MainActor.run { _ = NSWorkspace.shared.open(page) }

        let reply = try await receiver.waitForRedirect()
        guard reply["state"] == state else { throw GoogleError(message: "The sign-in didn't match. Please try again.") }
        if let e = reply["error"] {
            throw GoogleError(message: e == "access_denied" ? "Sign-in was cancelled." : "Google said: \(e)")
        }
        guard let code = reply["code"] else { throw GoogleError(message: "Google didn't send a sign-in code.") }

        var form = ["code": code, "client_id": clientID, "code_verifier": verifier,
                    "redirect_uri": redirect, "grant_type": "authorization_code"]
        if !secret.isEmpty { form["client_secret"] = secret }
        let json = try await post("https://oauth2.googleapis.com/token", form)
        guard let access = json["access_token"] as? String else { throw tokenError(json) }
        return Tokens(access: access,
                      expires: Date().addingTimeInterval((json["expires_in"] as? Double ?? 3600) - 60),
                      refresh: json["refresh_token"] as? String,
                      email: (json["id_token"] as? String).flatMap(emailFromIDToken))
    }

    /// A fresh access token from the saved refresh token.
    static func refresh(_ refresh: String, clientID: String, secret: String) async throws -> (String, Date) {
        var form = ["refresh_token": refresh, "client_id": clientID, "grant_type": "refresh_token"]
        if !secret.isEmpty { form["client_secret"] = secret }
        let json = try await post("https://oauth2.googleapis.com/token", form)
        guard let access = json["access_token"] as? String else { throw tokenError(json) }
        return (access, Date().addingTimeInterval((json["expires_in"] as? Double ?? 3600) - 60))
    }

    /// Tells Google to forget Mochi's access. Best effort: signing out locally happens either way.
    static func revoke(_ token: String) async {
        _ = try? await post("https://oauth2.googleapis.com/revoke", ["token": token])
    }

    private static func tokenError(_ json: [String: Any]) -> GoogleError {
        let code = json["error"] as? String ?? "unknown"
        if code == "invalid_grant" {
            return GoogleError(message: "Google ended the sign-in. Please sign in again.", signedOut: true)
        }
        let detail = json["error_description"] as? String ?? code
        return GoogleError(message: "Google sign-in failed: \(detail)", signedOut: code == "invalid_client")
    }

    private static func post(_ url: String, _ form: [String: String]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: url)!, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data(form.map { "\($0.key)=\(formEncode($0.value))" }.joined(separator: "&").utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    static func formEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    /// The account's email, from the middle part of the ID token Google returns with the tokens.
    /// (It came straight from Google over HTTPS, so it is only decoded here, not verified.)
    static func emailFromIDToken(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["email"] as? String
    }

    private static func randomString(_ length: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var rng = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars[Int(rng.next() % UInt64(chars.count))] })
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

/// A tiny one-shot web server on 127.0.0.1 that catches Google's redirect after you sign in.
/// It only listens on the loopback address, only while a sign-in is in progress, and stops after
/// the first proper reply (or three minutes).
final class LoopbackReceiver: @unchecked Sendable {     // all state is touched on `queue` only
    private var listener: NWListener?
    private var portWaiter: CheckedContinuation<UInt16, Error>?
    private var replyWaiter: CheckedContinuation<[String: String], Error>?
    private var reply: Result<[String: String], Error>?
    private let queue = DispatchQueue(label: "mochi.google.loopback")

    func start() async throws -> UInt16 {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let l = try NWListener(using: params)
        listener = l
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<UInt16, Error>) in
            queue.async { [weak self] in
                guard let self else { c.resume(throwing: CancellationError()); return }
                self.portWaiter = c
                l.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        if let p = l.port?.rawValue { self.portWaiter?.resume(returning: p); self.portWaiter = nil }
                    case .failed(let e):
                        self.portWaiter?.resume(throwing: e); self.portWaiter = nil
                        self.finish(.failure(e))
                    default: break
                    }
                }
                l.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
                l.start(queue: self.queue)
                self.queue.asyncAfter(deadline: .now() + 180) { [weak self] in
                    self?.finish(.failure(GoogleError(message: "The sign-in took too long. Please try again.")))
                }
            }
        }
    }

    func waitForRedirect() async throws -> [String: String] {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<[String: String], Error>) in
            queue.async {
                if let r = self.reply { c.resume(with: r) } else { self.replyWaiter = c }
            }
        }
    }

    func cancel() {
        queue.async { self.finish(.failure(GoogleError(message: "Sign-in was cancelled."))) }
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self else { conn.cancel(); return }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            // "GET /?code=…&state=… HTTP/1.1"
            let target = request.split(separator: "\r\n").first?.split(separator: " ").dropFirst().first.map(String.init) ?? ""
            let items = URLComponents(string: "http://127.0.0.1\(target)")?.queryItems ?? []
            var query: [String: String] = [:]
            for i in items { query[i.name] = i.value ?? "" }
            let isReply = query["code"] != nil || query["error"] != nil
            let body = isReply
                ? "<!doctype html><meta charset=utf-8><title>Mochi</title><body style=\"font:16px -apple-system;text-align:center;padding:60px\"><h2>🍡 All done!</h2><p>You can close this tab and go back to Mochi.</p>"
                : "Not found"
            let head = "HTTP/1.1 \(isReply ? "200 OK" : "404 Not Found")\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
            conn.send(content: Data((head + body).utf8), completion: .contentProcessed { _ in conn.cancel() })
            if isReply { self.finish(.success(query)) }
        }
    }

    /// Runs on `queue`.
    private func finish(_ result: Result<[String: String], Error>) {
        guard reply == nil else { return }
        reply = result
        listener?.cancel()
        listener = nil
        if case .failure(let e) = result { portWaiter?.resume(throwing: e); portWaiter = nil }
        replyWaiter?.resume(with: result)
        replyWaiter = nil
    }
}

// MARK: - The connection

/// Keeps the Google sign-in, syncs upcoming events every few minutes and hands the pet the reminders
/// that are due. Everything published here changes on the main thread.
final class GoogleCalendar: ObservableObject {
    static let shared = GoogleCalendar()

    enum Status: Equatable { case signedOut, signingIn, signedIn }

    @Published private(set) var status: Status = .signedOut
    @Published private(set) var email = ""
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var lastSync: Date?
    @Published private(set) var syncing = false
    @Published private(set) var problem: String?

    private let d = UserDefaults.standard
    private var access: (token: String, expires: Date)?
    private var schedule = AlarmSchedule()
    private var receiver: LoopbackReceiver?
    private var timer: Timer?
    static let syncEvery: TimeInterval = 5 * 60
    /// How far ahead to look. Google allows notifications up to four weeks early, but a week covers
    /// nearly everyone ("1 day before") without fetching a mountain of events.
    static let lookAhead: TimeInterval = 8 * 24 * 3600

    private init() {
        // Only touch the keychain once someone has actually signed in, so nobody else sees a prompt.
        if let e = d.string(forKey: "google.email") {
            email = e
            status = .signedIn
        }
    }

    // MARK: OAuth client

    /// Mochi needs an OAuth client ("Desktop app") from Google Cloud. `scripts/build-app.sh` writes one into
    /// the built app's Info.plist (GoogleClientID / GoogleClientSecret) from the GOOGLE_CLIENT_ID and
    /// GOOGLE_CLIENT_SECRET environment variables. Without it, Settings asks you to paste your own.
    /// (Google treats a Desktop app's secret as not truly secret; it is kept out of git all the same.)
    static var bundledClientID: String { infoString("GoogleClientID") }
    private static var bundledSecret: String { infoString("GoogleClientSecret") }
    private static func infoString(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var clientID: String {
        let own = PetSettings.shared.googleClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? Self.bundledClientID : own
    }
    var clientSecret: String {
        if !PetSettings.shared.googleClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Keychain.read(service: Keychain.google, account: "clientSecret")
        }
        return Self.bundledSecret
    }
    var hasClient: Bool { !clientID.isEmpty }

    func setClientSecret(_ s: String) {
        Keychain.write(s.trimmingCharacters(in: .whitespacesAndNewlines), service: Keychain.google, account: "clientSecret")
    }

    // MARK: Signing in and out

    func signIn() {
        guard status != .signingIn, hasClient else { return }
        problem = nil
        status = .signingIn
        let r = LoopbackReceiver()
        receiver = r
        let id = clientID, secret = clientSecret
        Task {
            do {
                let t = try await GoogleOAuth.signIn(clientID: id, secret: secret, receiver: r)
                await MainActor.run { self.signedIn(t) }
            } catch {
                await MainActor.run {
                    self.receiver = nil
                    self.status = .signedOut
                    self.problem = error.localizedDescription
                }
            }
        }
    }

    func cancelSignIn() { receiver?.cancel() }

    private func signedIn(_ t: GoogleOAuth.Tokens) {
        receiver = nil
        guard let refresh = t.refresh else {
            status = .signedOut
            problem = "Google didn't allow offline access. Please try again."
            return
        }
        Keychain.write(refresh, service: Keychain.google, account: "refreshToken")
        access = (t.access, t.expires)
        email = t.email ?? "Google account"
        d.set(email, forKey: "google.email")
        status = .signedIn
        NSApp.activate(ignoringOtherApps: true)
        sync()
    }

    func signOut() {
        let token = Keychain.read(service: Keychain.google, account: "refreshToken")
        if !token.isEmpty { Task { await GoogleOAuth.revoke(token) } }
        Keychain.write("", service: Keychain.google, account: "refreshToken")
        d.removeObject(forKey: "google.email")
        access = nil
        email = ""
        events = []
        lastSync = nil
        problem = nil
        status = .signedOut
    }

    // MARK: Syncing

    /// Starts the background sync (every five minutes, and on waking from sleep).
    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.syncIfStale() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self?.sync() }
        }
        syncIfStale()
    }

    private func syncIfStale() {
        guard status == .signedIn, PetSettings.shared.googleCalendarAlerts else { return }
        if let last = lastSync, Date().timeIntervalSince(last) < Self.syncEvery { return }
        sync()
    }

    func sync() {
        guard status == .signedIn, !syncing else { return }
        syncing = true
        let id = clientID, secret = clientSecret
        let saved = access
        Task {
            do {
                var token = saved
                if token == nil || token!.expires < Date() {
                    let refresh = Keychain.read(service: Keychain.google, account: "refreshToken")
                    guard !refresh.isEmpty else {
                        throw GoogleError(message: "Not signed in to Google any more. Please sign in again.", signedOut: true)
                    }
                    let fresh = try await GoogleOAuth.refresh(refresh, clientID: id, secret: secret)
                    token = (fresh.0, fresh.1)
                }
                let current = token!
                let events = try await Self.fetch(token: current.token)
                await MainActor.run {
                    self.access = current
                    self.synced(events)
                }
            } catch {
                await MainActor.run {
                    self.syncing = false
                    let e = error as? GoogleError
                    self.problem = e?.message ?? "Couldn't reach Google Calendar (\(error.localizedDescription))."
                    if e?.signedOut == true {
                        Keychain.write("", service: Keychain.google, account: "refreshToken")
                        self.d.removeObject(forKey: "google.email")
                        self.access = nil
                        self.events = []
                        self.status = .signedOut
                    }
                    // Try again sooner than the usual five minutes.
                    self.lastSync = Date().addingTimeInterval(-Self.syncEvery + 60)
                }
            }
        }
    }

    private func synced(_ list: [CalendarEvent]) {
        syncing = false
        problem = nil
        lastSync = Date()
        events = list
    }

    /// Calendars you have ticked in Google Calendar, then their events over the next week.
    private static func fetch(token: String) async throws -> [CalendarEvent] {
        let calendars: [GoogleCalendarEntry] = try await get(
            "https://www.googleapis.com/calendar/v3/users/me/calendarList",
            ["minAccessRole": "reader", "fields": "items(id,summary,selected,primary,defaultReminders)"],
            token: token, as: ItemList<GoogleCalendarEntry>.self).items ?? []
        let shown = calendars.filter { $0.selected == true || $0.primary == true }.prefix(20)

        let now = Date()
        var seen = Set<String>()
        var out: [CalendarEvent] = []
        for cal in shown {
            let list: [GoogleEvent] = try await get(
                "https://www.googleapis.com/calendar/v3/calendars/\(GoogleOAuth.formEncode(cal.id))/events",
                ["timeMin": GoogleTime.format(now.addingTimeInterval(-5 * 60)),
                 "timeMax": GoogleTime.format(now.addingTimeInterval(lookAhead)),
                 "singleEvents": "true", "orderBy": "startTime", "maxResults": "250",
                 "fields": "items(id,status,summary,start,reminders,attendees(self,responseStatus),eventType)"],
                token: token, as: ItemList<GoogleEvent>.self).items ?? []
            for e in list {
                guard let ev = e.reduced(calendarDefaults: cal.defaultReminders ?? []) else { continue }
                // The same meeting can show up in more than one of your calendars.
                if seen.insert("\(ev.title)@\(Int(ev.start.timeIntervalSince1970))").inserted { out.append(ev) }
            }
        }
        return out.sorted { $0.start < $1.start }
    }

    private struct ItemList<T: Decodable>: Decodable { let items: [T]? }

    private static func get<T: Decodable>(_ url: String, _ query: [String: String], token: String, as: T.Type) async throws -> T {
        var c = URLComponents(string: url)!
        c.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        // "+" in a time zone offset must not be read as a space.
        c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        var req = URLRequest(url: c.url!, timeoutInterval: 20)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw GoogleError(message: "Google ended the sign-in. Please sign in again.", signedOut: true) }
        if code == 403 {
            throw GoogleError(message: "Google Calendar refused the request. Is the Google Calendar API enabled for this OAuth client?")
        }
        guard (200..<300).contains(code) else { throw GoogleError(message: "Google Calendar answered with error \(code).") }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: For the pet

    var alarms: [CalendarAlarm] { events.flatMap { $0.alarms(atStart: PetSettings.shared.googleAlertAtStart) } }

    /// Reminders to say right now. Call about once a second, from the main thread.
    func due(now: Date = Date()) -> [CalendarAlarm] {
        guard status == .signedIn, !events.isEmpty else { return [] }
        return schedule.due(alarms, now: now)
    }

    /// Upcoming events that will get a reminder, for the settings page.
    var upNext: [CalendarEvent] {
        let now = Date()
        return events.filter { $0.start > now && !$0.alarms(atStart: PetSettings.shared.googleAlertAtStart).isEmpty }
    }
}
