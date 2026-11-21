import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var pet: PetController!
    private var companion: PetController?
    private var pauseReasons = Set<String>()
    private var settingsWindow: SettingsWindowController!
    private var statusItem: NSStatusItem!
    private lazy var askPanel = AskPanel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        pet = PetController()
        settingsWindow = SettingsWindowController(onSayHi: { [weak self] in self?.pet.greet() },
                                                  onBringBack: { [weak self] in self?.pet.bringBack() },
                                                  onTreat: { [weak self] in self?.pet.giveTreat() },
                                                  onPlay: { [weak self] in self?.pet.playBall() })
        pet.start()

        // Both menus are filled in just before they open, so the status lines are always current.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = makeMenu()
        pet.setContextMenu(makeMenu())              // right-click on the pet

        // A plain template glyph, so it follows the menu bar's light and dark appearance like every other icon.
        let glyph = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Mochi")
        glyph?.isTemplate = true
        statusItem.button?.image = glyph

        // Second pet: comes and goes with the setting.
        PetSettings.shared.$secondPet.receive(on: DispatchQueue.main).sink { [weak self] on in
            self?.setCompanion(on)
        }.store(in: &cancellables)

        // Calendar alerts need permission the first time they are switched on.
        PetSettings.shared.$calendarAlerts.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] on in
            guard on, let self else { return }
            self.pet.enableCalendar { ok in
                guard !ok else { return }
                PetSettings.shared.calendarAlerts = false
                self.pet.say("I need calendar access for that. Allow Mochi in System Settings › Privacy › Calendars.",
                             force: true, seconds: 8)
            }
        }.store(in: &cancellables)

        GoogleCalendar.shared.start()
        PetSettings.shared.$googleCalendarAlerts.dropFirst().receive(on: DispatchQueue.main).sink { on in
            if on { GoogleCalendar.shared.sync() }
        }.store(in: &cancellables)

        watchPower()
        if CommandLine.arguments.contains("--settings") { settingsWindow.show() }
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

    /// Nothing animates or polls while the Mac sleeps, the display is off, the screen is locked,
    /// or another user is logged in. This is what keeps Mochi off the battery when you are away.
    private func watchPower() {
        let ws = NSWorkspace.shared.notificationCenter
        let events: [(Notification.Name, String, Bool)] = [
            (NSWorkspace.willSleepNotification, "sleep", true),
            (NSWorkspace.didWakeNotification, "sleep", false),
            (NSWorkspace.screensDidSleepNotification, "display", true),
            (NSWorkspace.screensDidWakeNotification, "display", false),
            (NSWorkspace.sessionDidResignActiveNotification, "session", true),
            (NSWorkspace.sessionDidBecomeActiveNotification, "session", false)
        ]
        for (name, reason, pausing) in events {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.setPaused(pausing, reason)
            }
        }
        let dc = DistributedNotificationCenter.default()
        dc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.setPaused(true, "lock")
        }
        dc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.setPaused(false, "lock")
        }
    }

    private func setPaused(_ paused: Bool, _ reason: String) {
        if paused {
            pauseReasons.insert(reason)
            pet.pause(reason)
            companion?.pause(reason)
            AudioWatcher.shared.pause()
        } else {
            pauseReasons.remove(reason)
            pet.resume(reason)
            companion?.resume(reason)
            if pauseReasons.isEmpty { AudioWatcher.shared.resume() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DailyLog.shared.publish()
        PetMind.shared.save()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        return menu
    }

    /// Layout: a small status card, the things you do most, two submenus, then app controls.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let species = PetSettings.shared.species
        let name = species.name
        menu.removeAllItems()

        let header = NSMenuItem()
        let host = NSHostingView(rootView: MenuHeader(mind: .shared, species: species))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        header.view = host
        menu.addItem(header)
        menu.addItem(.separator())

        if PetAI.shared.on(.commands) {
            menu.addItem(item("Ask \(name)…", "text.bubble", #selector(ask), key: "k"))
        }
        menu.addItem(item("Give a Treat", "gift", #selector(giveTreat)))
        menu.addItem(item("Play Ball", "soccerball", #selector(playBall)))
        menu.addItem(submenu("Interact", "hand.wave", [
            item("Say Hi", "bubble.left", #selector(sayHi)),
            item("Pet \(name)", "heart", #selector(petIt)),
            item("Come Here", "cursorarrow.rays", #selector(comeHere)),
            item("Do a Trick", "sparkles", #selector(trick)),
            item("Power Move", "bolt", #selector(powerMove)),
            item("Go to Sleep", "moon.zzz", #selector(sleepNow)),
            item("Daily Check-in", "chart.bar", #selector(checkIn))
        ]))
        if let left = pet.focusMinutesLeft {
            menu.addItem(item("Stop Focus (\(left) min left)", "timer", #selector(stopFocus)))
        } else {
            menu.addItem(submenu("Focus Session", "timer", [15, 25, 50].map { minutes in
                let i = item("\(minutes) Minutes", nil, #selector(startFocus(_:)))
                i.tag = minutes
                return i
            }))
        }
        menu.addItem(.separator())
        menu.addItem(item("Bring \(name) Back", "arrow.uturn.backward", #selector(bringBack), key: "b"))
        menu.addItem(item("Settings…", "gearshape", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Mochi", nil, #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ symbol: String?, _ sel: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        if let symbol { i.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return i
    }

    private func submenu(_ title: String, _ symbol: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        let sub = NSMenu()
        sub.autoenablesItems = false
        items.forEach(sub.addItem)
        parent.submenu = sub
        return parent
    }

    /// Opens a text box above the pet; what you type is handed to the model (see `PetController.ask`).
    @objc private func ask() {
        let screen = pet.currentScreen.visibleFrame
        let above = NSPoint(x: pet.cx, y: pet.cy + pet.half + 46 * pet.scale)
        askPanel.show(above: above, in: screen, placeholder: "Ask \(PetSettings.shared.species.name) something…") { [weak self] text in
            self?.pet.ask(text)
        }
    }

    @objc private func sayHi() { pet.greet() }
    @objc private func petIt() { pet.petted() }
    @objc private func comeHere() { pet.comeHere() }
    @objc private func sleepNow() { pet.sleepNow() }
    @objc private func checkIn() { pet.checkIn() }
    @objc private func trick() { pet.trick() }
    @objc private func powerMove() { pet.powerMove() }
    @objc private func giveTreat() { pet.giveTreat() }
    @objc private func playBall() { pet.playBall() }
    @objc private func startFocus(_ sender: NSMenuItem) { pet.startFocus(minutes: sender.tag) }
    @objc private func stopFocus() { pet.stopFocus() }
    @objc private func bringBack() { pet.bringBack() }
    @objc private func openSettings() { settingsWindow.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
