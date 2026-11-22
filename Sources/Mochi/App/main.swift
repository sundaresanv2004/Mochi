#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

#if os(macOS)
// Earlier versions run with `swift run` saved under the name "Mochi"; the app now always uses its
// bundle identifier. Bring the old pet along the first time.
if UserDefaults.standard.object(forKey: "mind.firstMet") == nil, Bundle.main.bundleIdentifier != "Mochi",
   let old = UserDefaults.standard.persistentDomain(forName: "Mochi") {
    for (key, value) in old { UserDefaults.standard.set(value, forKey: key) }
}
#endif

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
    _ = NSApplication.shared
    Render.run(to: args[i + 1])
    #if os(macOS)
    Render.settings(to: args[i + 1].replacingOccurrences(of: ".png", with: "-settings.png"))
    #endif
    exit(0)
}

if args.contains("--social-test") {
    // Developer helper: steps two pets through every get-together without waiting, and prints what happens.
    _ = NSApplication.shared
    PetAI.shared.suspended = true
    let a = PetController(), b = PetController(isMain: false)
    a.buddy = b; b.buddy = a
    for kind in SocialKind.allCases {
        a.cx = a.platform.minX + 200; b.cx = a.cx + 420
        a.debug(.meet(kind))
        var last = ""
        for i in 0..<900 {
            a.tick(1.0 / 30); b.tick(1.0 / 30)
            let state = "\(a.social)/\(a.action) | \(b.social)/\(b.action)"
            if state != last { print(String(format: "%@ t=%.1fs  %@  gap=%.0f", kind.rawValue, Double(i) / 30, state, abs(a.cx - b.cx))); last = state }
            if i > 30, a.social == .none, b.social == .none, a.action != .visit { break }
        }
        a.apply(Decision(action: .idle, duration: 1)); b.apply(Decision(action: .idle, duration: 1))
    }
    exit(0)
}

if args.contains("--logic-test") { LogicTest.run() }
if let i = args.firstIndex(of: "--ai-test") { AITest.run(Array(args[(i + 1)...])) }

if args.contains("--screens-test") {
    // Developer helper: lists the displays and hops a pet across each of them in turn.
    _ = NSApplication.shared
    let all = NSScreen.screens
    for (i, sc) in all.enumerated() { print("display \(i + 1): frame \(sc.frame) visible \(sc.visibleFrame)") }
    let a = PetController()
    a.window.orderFrontRegardless()
    print("start on display \((all.firstIndex(of: a.currentScreen) ?? -1) + 1), neighbours left: \(a.neighborScreen(left: true) != nil) right: \(a.neighborScreen(left: false) != nil)")
    for _ in 0..<all.count {
        a.crossToNextScreen()
        for _ in 0..<120 { a.tick(1.0 / 30) }
        print("now on display \((all.firstIndex(of: a.currentScreen) ?? -1) + 1) at (\(Int(a.cx)), \(Int(a.cy))) surface \(a.surface) floor top \(Int(a.platform.top)) on-screen \(a.isOnScreen())")
    }
    exit(0)
}

if args.contains("--audio-test") {
    // Developer helper: prints what the audio watcher detects (for 12 seconds, or `--audio-test 60`).
    let w = AudioWatcher.shared
    w.start()
    let seconds = args.firstIndex(of: "--audio-test").flatMap { args.indices.contains($0 + 1) ? Double(args[$0 + 1]) : nil } ?? 12
    let began = Date()
    func stamp() -> String { String(format: "%5.1fs", Date().timeIntervalSince(began)) }
    var last: MediaActivity? = nil
    var lastCall: Bool? = nil
    var lastSources: [String] = []
    NotificationCenter.default.addObserver(forName: .mochiMediaChanged, object: nil, queue: .main) { _ in
        if w.current != last { last = w.current; print(stamp(), "media:", AudioWatcher.name(w.current)) }
        if w.onCall != lastCall { lastCall = w.onCall; print(stamp(), "on a call:", w.onCall ? "yes" : "no") }
    }
    let t = Timer(timeInterval: 0.25, repeats: true) { _ in
        if w.sources != lastSources { lastSources = w.sources; print(stamp(), "  heard:", w.sources.isEmpty ? "nothing" : w.sources.joined(separator: "; ")) }
    }
    RunLoop.main.add(t, forMode: .common)
    print(stamp(), "media:", AudioWatcher.name(w.current), "(watching for \(Int(seconds))s; play, pause or dictate now)")
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    exit(0)
}

#if os(macOS)
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon
EditMenu.install()                    // copy / paste shortcuts in text fields
app.run()
#else
WindowsApp.run()
#endif
