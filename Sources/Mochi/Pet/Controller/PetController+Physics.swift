#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Falling, landing, leaping, slipping and dragging.
extension PetController {
    func fall(_ dt: CGFloat, _ f: NSRect) {
        let prevFeet = cy - reach
        vy -= 1800 * dt
        cy += vy * dt
        if thrown {
            // Tumble through the air and bounce off the sides and the top of the screen.
            cx += vx * dt
            view.spin -= vx * dt * 0.012
            if cx < f.minX + reach { cx = f.minX + reach; vx = abs(vx) * 0.6 }
            if cx > f.maxX - reach { cx = f.maxX - reach; vx = -abs(vx) * 0.6 }
            if cy > f.maxY - reach { cy = f.maxY - reach; vy = -abs(vy) * 0.5 }
        } else {
            view.spin = 0
        }
        view.hop = 0
        let newFeet = cy - reach
        cx = clamp(cx, f.minX + reach, f.maxX - reach)
        view.mood = .held
        targetAngle = 0

        let hits = allPlatforms(f).filter { p in
            let inside = p.id == 0 || (cx >= p.minX && cx <= p.maxX)
            return inside && prevFeet >= p.top - 1 && newFeet <= p.top
        }
        if let best = hits.max(by: { $0.top < $1.top }) { land(on: best, f) }
    }

    func land(on p: Platform, _ f: NSRect) {
        if thrown {
            if abs(vy) > 420, bounces < 3 {
                // Still going fast: bounce.
                bounces += 1
                vy = abs(vy) * 0.45
                vx *= 0.7
                cy = p.top + reach + 1
                return
            }
            thrown = false
            vx = 0
            view.spin = 0
            platform = p
            surface = .floor
            vy = 0
            cx = clamp(cx, p.minX, p.maxX)
            cy = p.top + reach
            action = .dizzy
            remaining = 2.4
            targetAngle = 0
            say(Dialogue.crashLanded.randomElement() ?? "Whoa…", force: true)
            return
        }
        platform = p
        surface = .floor
        view.impact = min(1, abs(vy) / 900)        // squash on landing, harder after a long drop
        vy = 0
        view.spin = 0
        gait = 0
        cx = clamp(cx, p.minX, p.maxX)
        cy = p.top + reach
        if slipped {
            slipped = false
            say(Dialogue.ouch.randomElement() ?? "Ow!", force: true)
        } else if p.id != 0, Double.random(in: 0..<1) < 0.5 {
            say(Dialogue.landedWindow.randomElement() ?? "Nice!")
        }
        action = .idle
        remaining = 1.5
        targetAngle = 0
    }

    func startLeap() -> Bool {
        let feet = cy - reach
        guard let p = windowPlatforms.filter({ reachable($0, feet: feet) }).randomElement() else { return false }
        let end = CGPoint(x: clamp(cx, p.minX, p.maxX), y: p.top + reach)
        let start = CGPoint(x: cx, y: cy)
        let dist = hypot(end.x - start.x, end.y - start.y)
        facing = end.x >= start.x ? 1 : -1
        jump = Jump(start: start, end: end, t: 0,
                    duration: max(0.55, min(1.1, dist / 700 + 0.4)),
                    height: max(90, end.y - start.y + 70), target: p)
        surface = .air
        say(Dialogue.leaping.randomElement() ?? "Hup!")
        return true
    }

    func startSlip() {
        slipTimer = 0.8
        slipped = true
        say(Dialogue.slipping.randomElement() ?? "Uh oh…", force: true)
    }

    func letGo() {
        if surface == .leftWall { cx += 10 } else if surface == .rightWall { cx -= 10 }
        surface = .air
        vy = 0
        gripTime = 0
    }

    // MARK: Dragging

    func dragBegan() {
        held = true
        jump = nil
        thrown = false
        vx = 0
        dragVelocity = .zero
        hidePhase = .none
        slipTimer = 0
        slipped = false
        gripTime = 0
        view.spin = 0
        touch()
        if Double.random(in: 0..<1) < 0.35 { say(Dialogue.dragged.randomElement() ?? "Wheee!", force: true) }
    }

    func dragEnded() {
        held = false
        let f = screenFrame
        cx = window.frame.midX
        cy = window.frame.midY
        vy = 0
        gripTime = 0

        // Let go mid-swing and the pet goes flying.
        if hypot(dragVelocity.x, dragVelocity.y) > 650 {
            thrown = true
            bounces = 0
            vx = clamp(dragVelocity.x, -2400, 2400)
            vy = clamp(dragVelocity.y, -2400, 2600)
            cx = clamp(cx, f.minX + reach, f.maxX - reach)
            cy = min(cy, f.maxY - reach)
            surface = .air
            say(Dialogue.thrown.randomElement() ?? "Wheee!", force: true)
            return
        }

        // Let go close to a screen edge and the pet clings to it instead of dropping to the dock.
        let dl = cx - f.minX, dr = f.maxX - cx, dt = f.maxY - cy
        let nearest = min(dl, dr, dt)
        if settings.climbEdges && nearest < 95 {
            if nearest == dt { surface = .ceiling }
            else if nearest == dl { surface = .leftWall }
            else { surface = .rightWall }
            snap(f)
            action = .idle
            remaining = 2
            say(Dialogue.clung.randomElement() ?? "Got a grip!")
        } else {
            // Never let go outside the screen: pull it back inside before it falls.
            cx = clamp(cx, f.minX + reach, f.maxX - reach)
            cy = min(cy, f.maxY - reach)
            surface = .air
        }
    }
}
