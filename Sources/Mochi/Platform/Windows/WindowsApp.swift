#if os(Windows)
import Foundation
import AppKitLite
import WinSDK

/// The Windows app: the pets, and an icon in the notification area (bottom right of the taskbar) with the
/// same menu as the Mac's menu bar icon. Left- or right-click the icon, or right-click a pet, for the menu.
final class WindowsApp: NSApplicationDelegate {
    private static let shared = WindowsApp()
    private var pet: PetController!
    private var companion: PetController?
    private var pauseReasons = Set<String>()
    private var cancellables = Set<AnyCancellable>()
    private var tray: TrayIcon?

    static func run() {
        // Started by double-clicking (not from a terminal): the console Windows opened for us isn't wanted.
        var ids = [DWORD](repeating: 0, count: 4)
        if GetConsoleProcessList(&ids, DWORD(ids.count)) == 1 { FreeConsole() }
        let app = NSApplication.shared
        app.delegate = shared
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyCounter.shared.start()
        pet = PetController()
        pet.start()
        pet.setContextMenu(makeMenu())              // right-click on the pet

        let icon = TrayIcon(tooltip: "Mochi") { [weak self] in self?.drawTrayIcon() }
        icon.onClick = { [weak self] in self?.makeMenu().popUpAtCursor() }
        icon.onRightClick = icon.onClick
        NSApplication.shared.installTray(icon)
        tray = icon

        // Second pet: comes and goes with the setting.
        PetSettings.shared.$secondPet.receive(on: DispatchQueue.main).sink { [weak self] on in
            self?.setCompanion(on)
        }.store(in: &cancellables)

        // The tray icon shows the main pet.
        PetSettings.shared.$species.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.tray?.setImage { self?.drawTrayIcon() }
        }.store(in: &cancellables)

        GoogleCalendar.shared.start()
        PetSettings.shared.$googleCalendarAlerts.dropFirst().receive(on: DispatchQueue.main).sink { on in
            if on { GoogleCalendar.shared.sync() }
        }.store(in: &cancellables)

        VoiceControl.shared.attach(to: pet, &cancellables)
        watchPower()
        SettingsServer.shared.onAction = { [weak self] name, args in self?.settingsAction(name, args) }

        // Windows' UserDefaults only reaches the disk when asked: save every few seconds, and when Windows
        // shuts down or signs out (WM_QUERYENDSESSION / WM_ENDSESSION), so nothing is lost if Mochi is killed.
        let saver = Timer(timeInterval: 5, repeats: true) { _ in UserDefaults.standard.synchronize() }
        RunLoop.main.add(saver, forMode: .common)
        NSApplication.shared.onMessage = { msg, _, _ in
            if msg == 0x0011 || msg == 0x0016 { WindowsApp.saveEverything() }
        }
        if CommandLine.arguments.contains("--settings") { openSettings() }
    }

    /// The main pet's face, small, for the notification area.
    private func drawTrayIcon() {
        let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
        v.species = PetSettings.shared.species
        v.time = 0.6
        let ctx = NSGraphicsContext.current?.cgContext
        ctx?.saveGState()
        // Zoom in on the face: the pet fills most of its 120pt canvas.
        let k: CGFloat = 16 / 92
        ctx?.scaleBy(x: k, y: k)
        ctx?.translateBy(x: -14, y: -4)
        v.draw(v.bounds)
        ctx?.restoreGState()
    }

    private func setCompanion(_ on: Bool) {
        if on, companion == nil {
            let c = PetController(isMain: false)
            c.buddy = pet
            pet.buddy = c
            c.setContextMenu(makeMenu())
            c.start()
            pauseReasons.forEach { c.pause($0) }
            companion = c
        } else if !on, let c = companion {
            c.stop()
            pet.buddy = nil
            companion = nil
        }
    }

    // MARK: Power

    /// Nothing animates or polls while the PC sleeps, the display is off, the screen is locked,
    /// or another user is signed in.
    private func watchPower() {
        let ws = NSWorkspace.shared.notificationCenter
        let events: [(Notification.Name, String, Bool)] = [
            (NSWorkspace.willSleepNotification, "sleep", true),
            (NSWorkspace.didWakeNotification, "sleep", false),
            (NSWorkspace.screensDidSleepNotification, "display", true),
            (NSWorkspace.screensDidWakeNotification, "display", false),
            (NSWorkspace.sessionDidResignActiveNotification, "session", true),
            (NSWorkspace.sessionDidBecomeActiveNotification, "session", false),
            (NSWorkspace.screenLockedNotification, "lock", true),
            (NSWorkspace.screenUnlockedNotification, "lock", false)
        ]
        for (name, reason, pausing) in events {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.setPaused(pausing, reason)
            }
        }
    }

    private func setPaused(_ paused: Bool, _ reason: String) {
        if paused {
            pauseReasons.insert(reason)
            pet.pause(reason)
            companion?.pause(reason)
            AudioWatcher.shared.pause()
            VoiceControl.shared.block(reason)
        } else {
            pauseReasons.remove(reason)
            pet.resume(reason)
            companion?.resume(reason)
            if pauseReasons.isEmpty { AudioWatcher.shared.resume() }
            VoiceControl.shared.unblock(reason)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeyCounter.shared.stop()
        Self.saveEverything()
    }

    static func saveEverything() {
        DailyLog.shared.publish()
        PetMind.shared.save()
        UserDefaults.standard.synchronize()
    }

    // MARK: Menu

    /// Filled in just before it opens, so the status lines are always current.
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.willOpen = { [weak self, unowned menu] in self?.fill(menu) }
        return menu
    }

    /// Layout: the pet's status, the things you do most, two submenus, then app controls.
    private func fill(_ menu: NSMenu) {
        let name = PetSettings.shared.species.name
        let mind = PetMind.shared
        menu.removeAllItems()

        func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
        let status = NSMenuItem(title: "\(name) · \(mind.feeling.label)")
        status.isEnabled = false
        menu.addItem(status)
        let meters = NSMenuItem(title: "Energy \(pct(mind.energy))  ·  Tummy \(pct(mind.fullness))  ·  Joy \(pct(mind.joy))")
        meters.isEnabled = false
        menu.addItem(meters)
        menu.addItem(.separator())

        if PetAI.shared.on(.commands) {
            menu.addItem(withTitle: "Ask \(name)…") { [weak self] in self?.ask() }
        }
        menu.addItem(withTitle: "Talk to \(name)") { [weak self] in self?.talk() }
        menu.addItem(withTitle: "Give a Treat") { [weak self] in self?.pet.giveTreat() }
        menu.addItem(withTitle: "Play Ball") { [weak self] in self?.pet.playBall() }
        menu.addItem(submenu("Interact", [
            NSMenuItem(title: "Say Hi") { [weak self] in self?.pet.greet() },
            NSMenuItem(title: "Pet \(name)") { [weak self] in self?.pet.petted() },
            NSMenuItem(title: "Come Here") { [weak self] in self?.pet.comeHere() },
            NSMenuItem(title: "Do a Trick") { [weak self] in self?.pet.trick() },
            NSMenuItem(title: "Power Move") { [weak self] in self?.pet.powerMove() },
            NSMenuItem(title: "Go to Sleep") { [weak self] in self?.pet.sleepNow() },
            NSMenuItem(title: "Daily Check-in") { [weak self] in self?.pet.checkIn() }
        ]))
        if let left = pet.focusMinutesLeft {
            menu.addItem(withTitle: "Stop Focus (\(left) min left)") { [weak self] in self?.pet.stopFocus() }
        } else {
            menu.addItem(submenu("Focus Session", [15, 25, 50].map { minutes in
                NSMenuItem(title: "\(minutes) Minutes") { [weak self] in self?.pet.startFocus(minutes: minutes) }
            }))
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Bring \(name) Back") { [weak self] in self?.pet.bringBack() }
        menu.addItem(withTitle: "Settings…") { [weak self] in self?.openSettings() }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Mochi") { NSApp.terminate(nil) }
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title)
        let sub = NSMenu()
        items.forEach(sub.addItem)
        parent.submenu = sub
        return parent
    }

    /// Opens a text box above the pet; what you type is handed to the model (see `PetController.ask`).
    private func ask() {
        let screen = pet.currentScreen.visibleFrame
        let above = NSPoint(x: pet.cx, y: pet.cy + pet.half + 46 * pet.scale)
        AskBox.shared.show(above: above, in: screen, placeholder: "Ask \(PetSettings.shared.species.name) something…") { [weak self] text in
            self?.pet.ask(text)
        }
    }

    /// Listens for one spoken request; the pet shows what it hears and answers in its bubble.
    private func talk() { VoiceControl.shared.listenOnce(name: PetSettings.shared.species.name) }

    private func openSettings(_ page: String = "pet") { SettingsServer.shared.open(page: page) }

    /// The settings page's buttons.
    private func settingsAction(_ name: String, _ args: [String: Any]) {
        let ai = PetAI.shared, google = GoogleCalendar.shared, debug = PetDebug.shared
        switch name {
        case "treat": pet.giveTreat()
        case "play": pet.playBall()
        case "sayHi": pet.greet()
        case "bringBack": pet.bringBack()
        case "talk": talk()
        case "aiTest": ai.test()
        case "clearLines": ai.clearLines()
        case "writeDiary": ai.writeDiary(DailyLog.shared.current)
        case "forget": if let i = (args["index"] as? NSNumber)?.intValue { PetMemory.shared.forget(at: i) }
        case "forgetAll": PetMemory.shared.forgetEverything()
        case "googleSignIn": google.signIn()
        case "googleCancel": google.cancelSignIn()
        case "googleSync": google.sync()
        case "googleSignOut": google.signOut()
        case "testReminder": if let k = (args["kind"] as? String).flatMap(ReminderKind.init) { debug.fire?(.reminder(k)) }
        case "testStretch": debug.fire?(.stretch)
        case "testCalendar": debug.fire?(.calendar)
        case "checkIn": debug.fire?(.checkIn)
        case "skip": debug.fire?(.skip(minutes: (args["minutes"] as? NSNumber)?.intValue ?? 5))
        case "nextScreen": debug.fire?(.nextScreen)
        case "meet": if let k = SocialKind.allCases.first(where: { "\($0)" == args["kind"] as? String }) { debug.fire?(.meet(k)) }
        default: break
        }
    }
}
#endif
