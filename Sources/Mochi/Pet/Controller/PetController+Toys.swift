#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Treats and the ball.
extension PetController {
    /// Returns true while the pet is busy with the treat.
    func handleTreat(_ t: Treat, _ dt: CGFloat, _ f: NSRect) -> Bool {
        // Treats land on the Dock floor: come down from walls, the ceiling or windows first.
        if surface != .floor {
            letGo()
            return true
        }
        if platform.id != 0 {
            surface = .air
            vy = 0
            cx += (t.x >= cx ? 1 : -1) * 30
            return true
        }
        let dx = t.x - cx
        if t.landed, abs(dx) < 28 {
            t.remove()
            treat = nil
            mind.fed()
            log.gaveTreat()
            view.spawnHearts(4)
            say(Dialogue.yum.randomElement() ?? "Yum!", force: true)
            apply(Decision(action: .happy, duration: 2.2))
            return true
        }
        if abs(dx) > 12 {
            facing = dx > 0 ? 1 : -1
            view.mood = .chase
            cx += facing * chaseSpeed * 1.1 * dt
        } else {
            view.mood = .idle
        }
        snap(f)
        targetAngle = 0
        return true
    }

    // MARK: Playing ball

    /// Returns true while the pet is busy with the ball.
    func handleBall(_ b: Ball, _ dt: CGFloat, _ f: NSRect, _ now: Date) -> Bool {
        // The ball bounces along the Dock floor: come down from walls, the ceiling or windows first.
        if surface != .floor {
            letGo()
            return true
        }
        if platform.id != 0 {
            surface = .air
            vy = 0
            cx += (b.x >= cx ? 1 : -1) * 30
            return true
        }
        if b.kicks >= 25 || now.timeIntervalSince(b.born) > 50 {
            endBall(celebrate: true)
            return true
        }
        let dx = b.x - cx
        if abs(dx) < 32, b.canKick {
            // The longer the rally, the likelier a miss: that ends the game and sets the score.
            if b.kicks >= 3, Double.random(in: 0..<1) < min(0.45, 0.07 * Double(b.kicks - 2)) {
                endBall(celebrate: true)
                return true
            }
            // Kick it away, but back towards the middle when it is near a screen edge.
            var dir: CGFloat = dx >= 0 ? 1 : -1
            if b.x < f.minX + 220 { dir = 1 } else if b.x > f.maxX - 220 { dir = -1 }
            b.kick(vx: dir * .random(in: 240...440), vy: .random(in: 420...640))
            facing = dir
            view.mood = .happy
            if now.timeIntervalSince(lastKickLine) > 2.5 {
                lastKickLine = now
                say(Dialogue.kick.randomElement() ?? "Boing!")
            }
        } else if abs(dx) > 14 {
            facing = dx > 0 ? 1 : -1
            view.mood = .chase
            cx += facing * chaseSpeed * 1.25 * dt
        } else {
            view.mood = .idle
        }
        snap(f)
        targetAngle = 0
        return true
    }

    func endBall(celebrate: Bool) {
        guard let b = ball else { return }
        b.remove()
        ball = nil
        guard celebrate else { return }
        mind.played()
        log.played()
        view.spawnHearts(4)
        // Score the rally and remember the best one.
        let best = UserDefaults.standard.integer(forKey: "bestRally")
        let record = b.kicks > best && b.kicks >= 3
        if record {
            UserDefaults.standard.set(b.kicks, forKey: "bestRally")
            if PetAI.shared.on(.memory) { PetMemory.shared.note("New ball rally record together: \(b.kicks) kicks") }
        }
        say(b.kicks == 0 ? (Dialogue.playedEnough.randomElement() ?? "That was fun!")
                         : Dialogue.rally(b.kicks, record: record), force: true, seconds: 4.5)
        action = .happy
        remaining = 2.2
    }
}
