#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Cursor reactions (shake, hover) and typing along.
extension PetController {
    func trackCursor(_ dt: CGFloat, _ now: Date) {
        let m = NSEvent.mouseLocation
        let delta = CGPoint(x: m.x - lastMouse.x, y: m.y - lastMouse.y)
        lastMouse = m

        // Shaking the mouse hard near the pet makes it dizzy.
        if hypot(delta.x, delta.y) / max(dt, 0.001) > 700 {
            if delta.x * lastMouseDelta.x + delta.y * lastMouseDelta.y < 0 { shake += 1 }
            lastMouseDelta = delta
        }
        shake = max(0, shake - dt * 1.5)

        let dist = hypot(m.x - cx, m.y - (cy - 20 * scale))
        let calm = canAct && !userAway
        if shake >= 5, dist < 350, calm, now > dizzyCooldown {
            shake = 0
            dizzyCooldown = now.addingTimeInterval(15)
            apply(Decision(action: .dizzy, duration: 2.8))
            say("Whoa… everything's spinning 😵‍💫")
        }

        // Hovering the cursor over the pet without clicking gets a happy reaction.
        if calm, dist < 48 * scale, action != .sleep, action != .dizzy {
            hoverTime += dt
            if hoverTime > 1.2, !hoverReacted {
                hoverReacted = true
                view.spawnHearts(2)
                say(Dialogue.hover.randomElement() ?? "Hi!")
                action = .happy
                remaining = 1.2
            }
        } else if dist > 60 * scale {
            hoverTime = 0
            hoverReacted = false
        }
    }

    // MARK: Typing along

    func trackTyping(_ dt: CGFloat, _ now: Date) {
        let count = SystemInfo.keyPressCount()
        let keys = count >= keyCount ? Double(count - keyCount) : 0
        keyCount = count
        guard settings.reactToTyping else {
            typingRate = 0; typingStreak = 0; fastTyping = 0
            return
        }
        let t = Double(dt)
        typingRate += (keys / t - typingRate) * min(1, t * 1.5)
        if keys > 0 {
            lastKey = now
            view.tap = 1                           // bop along with each key
        }

        // A streak survives short thinking pauses and ends after a real break.
        let pause = now.timeIntervalSince(lastKey)
        if pause < 2.5 { typingStreak += t; if isMain { log.typed(t) } }
        else if pause > 8 { typingStreak = 0; nextTypingCheer = 60 }
        fastTyping = typingRate > 7 ? fastTyping + t : max(0, fastTyping - t)

        guard isMain, canAct, !userAway, action != .sleep, treat == nil, ball == nil else { return }
        if fastTyping > 4, now > fastCheerAfter {
            fastTyping = 0
            fastCheerAfter = now.addingTimeInterval(180)
            say(Dialogue.typingFast.randomElement() ?? "Speedy!")
            action = .happy
            remaining = 1.4
        } else if typingStreak >= nextTypingCheer {
            // Cheer at one minute, at five, then every ten.
            let long = nextTypingCheer >= 300
            nextTypingCheer = nextTypingCheer < 300 ? 300 : nextTypingCheer + 600
            view.spawnHearts(2)
            say((long ? Dialogue.typingLong : Dialogue.typingRoll).randomElement() ?? "Nice!")
        }
    }
}
