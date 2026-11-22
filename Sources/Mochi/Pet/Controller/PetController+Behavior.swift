#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Applying decisions, speaking, and acting them out each frame.
extension PetController {
    func touch() { lastInteraction = Date() }

    func apply(_ d: Decision, forceSay: Bool = false) {
        action = d.action
        remaining = d.duration
        forceClimb = false
        hidePhase = .none
        social = .none
        if let line = d.line { say(line) }
        switch d.action {
        case .walk(let axis):
            facing = map(axis, surface)
        case .chase where !settings.followCursor:
            action = .idle
        case .leap:
            if !startLeap() { action = .idle; remaining = 1.5 }
        case .climbEdge:
            if surface == .floor, platform.id == 0, settings.climbEdges {
                let toLeft = (cx - platform.minX) < (platform.maxX - cx)
                let axis: CGFloat = toLeft ? -1 : 1
                facing = map(axis, surface)
                action = .walk(axis: axis)
                forceClimb = true
            } else {
                action = .idle
                remaining = 1.5
            }
        case .hide:
            if surface == .floor, platform.id == 0, NSScreen.screens.count == 1 {
                hideSide = (cx - platform.minX) < (platform.maxX - cx) ? -1 : 1
                facing = hideSide
                hidePhase = .going
            } else {
                action = .idle
                remaining = 1.5
            }
        case .power:
            if forceSay || Double.random(in: 0..<1) < 0.6 {
                say(Dialogue.power(species).randomElement() ?? "Ta-daa!", force: forceSay)
            }
        case .flip, .spin:
            flipLength = max(0.3, d.duration)
        case .greet:
            // With AI on, every third unprompted hello is about what is actually going on.
            if !forceSay, PetAI.shared.on(.reactions), Int.random(in: 0..<3) == 0 {
                react("You feel like saying something to your human: about the time of day, what is going on, or something you remember about them",
                      fallback: greetingLine())
            } else {
                say(greetingLine(), force: forceSay)
            }
        case .stretch:
            if Double.random(in: 0..<1) < 0.5 { say("*yaaawn*") }
        case .dance:
            if media == .none, Double.random(in: 0..<1) < 0.5 { say("♪ La la la ♪") }
        case .zoomies:
            if Double.random(in: 0..<1) < 0.5 { say("Zoomies!!") }
        default:
            break
        }
        // Acrobatics need the ground: hanging from the top of the screen or a wall, it just looks pleased instead.
        if surface != .floor {
            switch action {
            case .spin, .flip, .zoomies:
                action = .happy
                remaining = min(remaining, 1.5)
            default:
                break
            }
        }
        view.spin = 0
    }

    /// Safety net against a pet that looks frozen: if it hasn't moved for a while and nothing explains it
    /// (a call, a video, a focus session, you being away, exhaustion), it gets up and wanders.
    func stayLively(_ dt: CGFloat, _ f: NSRect) {
        if hypot(cx - lastSpot.x, cy - lastSpot.y) > 3 {
            lastSpot = CGPoint(x: cx, y: cy)
            stillFor = 0
            return
        }
        stillFor += TimeInterval(dt)
        let excused = userAway || focusing || media.isWatching || mind.energy < 0.08
            || social != .none || hidePhase != .none || treat != nil || ball != nil || slipTimer > 0
        guard !excused, stillFor > (action == .sleep ? 90 : 40) else { return }
        stillFor = 0
        let axis: CGFloat = context(f).axisFraction < 0.5 ? 1 : -1
        apply(Decision(action: .walk(axis: axis), duration: .random(in: 3...6)))
        if Double.random(in: 0..<1) < 0.6 { say(species.lines.randomElement() ?? "Hi!") }
    }

    func greetingLine() -> String {
        Dialogue.greeting(species: species, hour: hour, bondLevel: mind.level, days: mind.daysTogether)
    }

    func scheduleGreeting(_ now: Date) {
        if let r = settings.chattiness.interval {
            // A companion chimes in about half as often as the main pet.
            nextGreeting = now.addingTimeInterval(.random(in: r) * (isMain ? 1 : 2.2))
        } else {
            nextGreeting = now.addingTimeInterval(60)
        }
    }

    func maybeGreet(_ now: Date) {
        guard now >= nextGreeting else { return }
        scheduleGreeting(now)
        if social != .none { return }               // busy with the other pet
        if settings.chattiness != .off, action != .sleep, !bubble.visible, !onCall, !media.isWatching, !userAway, !focusing {
            apply(Decision(action: .greet, duration: 2.2))
        }
    }

    /// Whether a bubble would be shown right now.
    func canSpeak(force: Bool) -> Bool {
        if force { return true }
        // Quiet during calls, films and focus sessions.
        return settings.chattiness != .off && !onCall && media != .movie && !focusing
    }

    func say(_ text: String, force: Bool = false, seconds: TimeInterval = 3.6) {
        guard canSpeak(force: force) else { return }
        // With AI on, a canned line is swapped for one the model wrote for the same moment.
        let text = PetAI.shared.restyle(text, species: species)
        lastSaid = text
        saidCount += 1
        bubble.say(text, for: seconds)
    }

    func behave(_ dt: CGFloat, _ f: NSRect) {
        // Spin and hop are worked out fresh every frame, so an interrupted trick can never leave the pet tilted.
        var spin: CGFloat = 0
        var hop: CGFloat = 0
        if action != .visit { social = .none }      // something else took over: the get-together is off
        switch action {
        case .idle, .leap, .climbEdge:
            view.mood = .idle
            lookAtCursor()
        case .sleep:
            view.mood = .sleep
        case .happy, .greet:
            view.mood = .happy
        case .walk:
            view.mood = .walk
            advance(species.walkSpeed * dt, autonomous: true, f)
        case .chase:
            chase(dt, f)
        case .stretch:
            view.mood = .stretch
        case .dance:
            view.mood = .dance
        case .spin:
            // one full twirl, easing in and out
            let t = CGFloat(min(1, max(0, 1 - remaining / flipLength)))
            view.mood = .happy
            spin = 2 * .pi * t * t * (3 - 2 * t)
        case .dizzy:
            view.mood = .dizzy
            spin = sin(view.time * 10) * 0.1
        case .mope:
            view.mood = .sad
        case .power:
            view.mood = .power
            if species == .dino || species == .wolf { spin = sin(view.time * 44) * 0.045 }   // shaking with the roar
        case .flip:
            // up, all the way round, and back down on its feet
            let t = CGFloat(min(1, max(0, 1 - remaining / flipLength)))
            view.mood = .jump
            spin = -facing * 2 * .pi * t
            hop = sin(t * .pi) * 34
        case .hide:
            hideAndPeek(dt, f)
        case .visit:
            visitBuddy(dt, f)
        case .lookAround:
            view.mood = .idle
            facing = sin(view.time * 2.5) > 0 ? 1 : -1
        case .zoomies:
            view.mood = .chase
            if Double.random(in: 0..<1) < 0.03 { turnAround() }
            advance(species.walkSpeed * 3.5 * dt, autonomous: true, f)
        }
        view.spin = spin
        view.hop = hop
        snap(f)
    }

    func context(_ f: NSRect) -> PetContext {
        let frac: CGFloat
        switch surface {
        case .floor: frac = (cx - platform.minX) / max(1, platform.maxX - platform.minX)
        case .ceiling: frac = (cx - (f.minX + reach)) / max(1, f.width - 2 * reach)
        case .leftWall, .rightWall: frac = (cy - (f.minY + reach)) / max(1, f.height - 2 * reach)
        case .air: frac = 0.5
        }
        let m = NSEvent.mouseLocation
        let feet = cy - reach
        return PetContext(surface: surface,
                          axisFraction: frac,
                          cursorDistance: hypot(m.x - cx, m.y - cy),
                          secondsSinceInteraction: Date().timeIntervalSince(lastInteraction),
                          hour: hour,
                          platformAbove: surface == .floor && windowPlatforms.contains { reachable($0, feet: feet) },
                          canClimb: surface == .floor && platform.id == 0 && settings.climbEdges,
                          canHide: surface == .floor && platform.id == 0 && NSScreen.screens.count == 1,
                          media: media,
                          onCall: onCall,
                          userAway: userAway,
                          focusing: focusing,
                          species: species,
                          energy: mind.energy,
                          fullness: mind.fullness,
                          joy: mind.joy,
                          bondLevel: mind.level)
    }
}
