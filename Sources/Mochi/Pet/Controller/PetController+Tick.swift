import AppKit

/// The per-frame update: physics, grip, toys, decisions, then drawing and the bubble.
extension PetController {
    func tick(_ dt: CGFloat) {
        let now = Date()
        var f = screenFrame
        view.advance(dt)
        refreshPlatforms(now, f)
        f = screenFrame                            // the Dock may have just appeared or gone
        if platform.id == 0 {
            let floor = dock(f)
            // The floor dropped away (the Dock was hidden): fall to the new one instead of teleporting.
            if surface == .floor, jump == nil, !held, floor.top < platform.top - 10 { surface = .air; vy = 0 }
            platform = floor
        }
        slowTick(now)

        if let t = treat {
            t.update(dt, floorY: f.minY - 2)
            if now.timeIntervalSince(t.born) > 40 { t.remove(); treat = nil }
        }
        if let b = ball {
            b.update(dt, floorY: f.minY - 2, minX: f.minX + 30, maxX: f.maxX - 30)
            if now.timeIntervalSince(b.born) > 45 { endBall(celebrate: false) }
        }

        // Safety net: if the pet ever ends up outside every screen, bring it back.
        if !held, jump == nil, !isOnScreen() { bringBack() }

        trackCursor(dt, now)
        trackTyping(dt, now)

        if held {
            // Remember how fast the pet is being dragged, so letting go mid-swing throws it.
            let px = window.frame.midX, py = window.frame.midY
            dragVelocity.x = dragVelocity.x * 0.55 + (px - cx) / dt * 0.45
            dragVelocity.y = dragVelocity.y * 0.55 + (py - cy) / dt * 0.45
            cx = px
            cy = py
            view.mood = .held
            view.hop = 0
            targetAngle = 0
        } else if var j = jump {
            view.spin = 0
            view.hop = 0
            j.t += dt / j.duration
            if j.t >= 1 {
                jump = nil
                land(on: j.target, f)
            } else {
                jump = j
                cx = j.start.x + (j.end.x - j.start.x) * j.t
                cy = j.start.y + (j.end.y - j.start.y) * j.t + sin(j.t * .pi) * j.height
                view.mood = .jump
                targetAngle = 0
            }
        } else if surface == .air {
            fall(dt, f)
        } else if surface != .floor && !settings.climbEdges {
            surface = .air; vy = 0                 // climbing turned off: let go
        } else {
            if surface == .floor { gripTime = 0 }
            else {
                gripTime += TimeInterval(dt)
                if slipTimer > 0 {
                    // Losing grip: wobble, then fall.
                    slipTimer -= dt
                    view.mood = .held
                    view.spin = sin(view.time * 38) * 0.14
                    targetAngle = angle(for: surface)
                    if slipTimer <= 0 { view.spin = 0; letGo() }
                    finish(dt, f)
                    return
                }
                // Grips are strong for the first ~30s, then slowly get tired.
                // Roughly: a slip every minute or two of hanging around, rarer on walls than the ceiling.
                let tired = max(0, gripTime - 30)
                let rate = (surface == .ceiling ? 0.006 : 0.003) + min(0.02, tired * 0.0004)
                if gripTime > 30, Double.random(in: 0..<1) < rate * Double(dt) { startSlip() }
            }

            // Ease in and out of a walk instead of starting and stopping dead.
            let moving = view.mood == .walk || view.mood == .chase
            gait += ((moving ? 1 : 0.1) - gait) * min(1, dt * 7)

            if let t = treat, handleTreat(t, dt, f) {
                finish(dt, f)
                return
            }
            if let b = ball, handleBall(b, dt, f, now) {
                finish(dt, f)
                return
            }

            remaining -= TimeInterval(dt)
            stayLively(dt, f)
            maybeGreet(now)
            maybeVisit(dt)
            if remaining <= 0 { apply(brain.nextDecision(context(f))) }
            behave(dt, f)
            targetAngle = angle(for: surface)
        }
        finish(dt, f)
    }

    func finish(_ dt: CGFloat, _ f: NSRect) {
        if surface != loggedSurface {
            let what: String
            switch surface {
            case .air: what = held ? "Picked up" : (thrown ? "Thrown" : (jump != nil ? "Jumping" : "Falling"))
            case .floor: what = platform.id == 0 ? "Landed on the Dock" : "Landed on a window"
            default: what = "Clinging to the \(surface.label)"
            }
            DebugLog.add(.movement, what, pet: species.name)
            loggedSurface = surface
        }
        // Smoothly rotate onto the new surface.
        var diff = targetAngle - view.angle
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        view.angle += diff * min(1, dt * 10)

        // Eyes follow the cursor (converted into the pet's rotated frame).
        let m = NSEvent.mouseLocation
        let vx = m.x - cx, vyy = m.y - (cy - 20 * scale)
        let dist = hypot(vx, vyy)
        let ux = dist > 1 ? vx / dist : 0, uy = dist > 1 ? vyy / dist : 0
        let a = view.angle
        let strength = min(1, dist / 150) * 2.6
        view.gaze = CGPoint(x: (ux * cos(a) + uy * sin(a)) * strength,
                            y: (-ux * sin(a) + uy * cos(a)) * strength)
        // Turn the head round over a few frames rather than flipping it.
        view.facing += (facing - view.facing) * min(1, dt * 16)
        if abs(facing - view.facing) < 0.02 { view.facing = facing }

        // Hide and peek: slide past the screen edge until only half the face shows.
        let hidden = action == .hide && hidePhase == .hidden
        hideShift += ((hidden ? hideSide * (reach + 2 * scale) : 0) - hideShift) * min(1, dt * 9)
        if abs(hideShift) < 0.3, !hidden { hideShift = 0 }
        let origin = NSPoint(x: cx - half + hideShift, y: cy - half)
        if origin != window.frame.origin { window.setFrameOrigin(origin) }     // moving a window isn't free
        view.needsDisplay = true

        if bubble.visible {
            let k = scale
            let head = (species.headRoom + view.outfit.headRoom) * k
            switch surface {
            case .ceiling:
                bubble.update(centerX: cx, aboveY: cy + 46 * k, belowY: cy - 4 * k - head - 2, preferBelow: true, limit: f)
            case .leftWall, .rightWall:
                bubble.update(centerX: cx, aboveY: cy + 46 * k, belowY: cy - 46 * k, preferBelow: false, limit: f)
            default:
                bubble.update(centerX: cx, aboveY: cy + 4 * k + head + 2, belowY: cy - 60 * k, preferBelow: false, limit: f)
            }
        }
    }
}
