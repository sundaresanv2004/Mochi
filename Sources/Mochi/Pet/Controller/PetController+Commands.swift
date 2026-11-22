#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// What you can ask the pet to do (menu bar, right-click, settings), and focus sessions.
extension PetController {
    var wornOutfit: Outfit {
        isMain && settings.outfit.unlockLevel <= mind.level ? settings.outfit : .none
    }

    /// Focus sessions belong to the main pet; a companion keeps quiet along with it.
    var focusing: Bool { (isMain ? focusEnds : buddy?.focusEnds) != nil }

    func greet() {
        touch()
        if surface != .air { apply(Decision(action: .greet, duration: 2.2), forceSay: true) }
        else { say(greetingLine(), force: true) }
    }

    func petted() {
        touch()
        let now = Date()
        clickStreak = now.timeIntervalSince(lastClick) < 1.5 ? clickStreak + 1 : 1
        lastClick = now

        let wasSleeping = action == .sleep
        mind.petted()
        log.petted()
        view.spawnHearts(3)
        if clickStreak >= 5 {
            say("Okay okay, I love you too! 💖", force: true)
            clickStreak = 0
        } else {
            say((wasSleeping ? Dialogue.startled : Dialogue.petted).randomElement() ?? "Hehe!", force: true)
        }
        action = .happy
        remaining = 1.8
        buddy?.noticedPetting(of: self)
    }

    func sleepNow() {
        touch()
        action = .sleep
        remaining = 30
        say("Zzz…", force: true)
    }

    func comeHere() {
        touch()
        apply(Decision(action: .chase, duration: 8))
        say("Coming!", force: true)
    }

    /// Drops a snack from the top of the screen (under the mouse) for the pet to eat.
    func giveTreat() {
        guard treat == nil else { return }
        touch()
        if mind.isStuffed {
            say(Dialogue.stuffed.randomElement() ?? "I'm stuffed!", force: true)
            return
        }
        endBall(celebrate: false)
        let f = screenFrame
        let x = clamp(NSEvent.mouseLocation.x, f.minX + 60, f.maxX - 60)
        treat = Treat(emoji: species.treatEmoji, x: x, y: f.maxY - 40)
        say(Dialogue.treatDropped.randomElement() ?? "Ooh, a treat!", force: true)
    }

    /// Drops a bouncy toy near the mouse; the pet chases it and kicks it around for a while.
    func playBall() {
        guard ball == nil, treat == nil else { return }
        touch()
        if mind.energy < 0.1 {
            say(Dialogue.tooTired.randomElement() ?? "Too tired…", force: true)
            return
        }
        let f = screenFrame
        let x = clamp(NSEvent.mouseLocation.x, f.minX + 60, f.maxX - 60)
        ball = Ball(emoji: species.toyEmoji, x: x, y: f.minY + 260)
        say(Dialogue.ballDropped.randomElement() ?? "Ball!", force: true)
    }

    // MARK: Focus sessions

    var focusMinutesLeft: Int? {
        focusEnds.map { max(1, Int(ceil($0.timeIntervalSinceNow / 60))) }
    }

    /// The pet keeps quiet and calm for `minutes`, then celebrates with you.
    func startFocus(minutes: Int) {
        touch()
        focusEnds = Date().addingTimeInterval(TimeInterval(minutes * 60))
        focusPlanned = minutes
        activeSeconds = 0
        endBall(celebrate: false)
        say(Dialogue.focusStart.randomElement() ?? "Focus time!", force: true)
        if canAct { apply(Decision(action: .idle, duration: 4)) }
    }

    func stopFocus() {
        guard focusEnds != nil else { return }
        focusEnds = nil
        say(Dialogue.focusStopped.randomElement() ?? "Okay, break time!", force: true)
    }

    /// Says how today has gone so far (menu: Daily Check-in).
    func checkIn() {
        touch()
        say(log.current.summary(prefix: "Today"), force: true, seconds: 7)
        if canAct { apply(Decision(action: .happy, duration: 1.6)) }
    }

    func finishFocus() {
        focusEnds = nil
        activeSeconds = 0
        mind.focusedTogether()
        log.focused(minutes: focusPlanned)
        view.spawnHearts(5)
        react("Your human just finished a \(focusPlanned)-minute focus session with you beside them: celebrate and suggest a break",
              fallback: Dialogue.focusDone.randomElement() ?? "Focus done! 🎉", force: true, note: true)
        if canAct { apply(Decision(action: .dance, duration: 5)) }
    }

    /// The pet's signature move: fire for the dragon, lightning for the robot, a roar for the dino…
    func powerMove() {
        touch()
        if canAct { apply(Decision(action: .power, duration: 2.2), forceSay: true) }
    }

    /// A random trick, on demand (menu bar / right-click).
    func trick() {
        touch()
        let options: [Decision] = [
            Decision(action: .dance, duration: 4),
            Decision(action: .spin, duration: 0.9),
            Decision(action: .stretch, duration: 2.4),
            Decision(action: .zoomies, duration: 3.5),
            Decision(action: .lookAround, duration: 3),
            Decision(action: .flip, duration: 0.8),
            Decision(action: .power, duration: 2.2)
        ]
        if canAct, let d = options.randomElement() { apply(d) }
    }

    /// Rescue: put the pet back on screen and let it drop in from the top.
    func bringBack() {
        touch()
        held = false
        jump = nil
        thrown = false
        vx = 0
        hidePhase = .none
        let f = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        surface = .air
        vy = 0
        cx = f.midX
        cy = f.maxY - 100
        view.angle = 0
        targetAngle = 0
        view.spin = 0
        window.setFrameOrigin(NSPoint(x: cx - half, y: cy - half))
        window.orderFrontRegardless()
        say("Phew, I'm back!", force: true)
    }
}
