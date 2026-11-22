#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Hide and peek, chasing and walking along surfaces.
extension PetController {
    func hideAndPeek(_ dt: CGFloat, _ f: NSRect) {
        switch hidePhase {
        case .going:
            view.mood = .walk
            advance(species.walkSpeed * 1.4 * dt, autonomous: true, f)   // floorEnd() ducks behind the edge
        case .hidden:
            view.mood = .idle
            facing = -hideSide
            let m = NSEvent.mouseLocation
            // Pop out when you come looking, or when it gets bored of waiting.
            if hypot(m.x - cx, m.y - cy) < 190 || remaining < 1.7 {
                hidePhase = .none
                action = .happy
                remaining = 1.6
                view.spawnHearts(2)
                say(Dialogue.peekaboo.randomElement() ?? "Peekaboo!")
            }
        case .none:
            view.mood = .idle
        }
    }

    /// Distance from the pet to the cursor along the current surface's axis.
    func cursorDelta() -> CGFloat {
        let m = NSEvent.mouseLocation
        switch surface {
        case .floor, .ceiling: return m.x - cx
        case .leftWall, .rightWall: return m.y - cy
        case .air: return 0
        }
    }

    func lookAtCursor() {
        let d = cursorDelta()
        let m = NSEvent.mouseLocation
        if abs(d) > 40, hypot(m.x - cx, m.y - cy) < 500 {
            facing = map(d > 0 ? 1 : -1, surface)
        }
    }

    func chase(_ dt: CGFloat, _ f: NSRect) {
        let d = cursorDelta()
        if abs(d) < 28 {
            view.mood = .idle
            return
        }
        // The cursor is on the next display: follow it over.
        if onDock, d < 0 ? cx <= platform.minX + 2 : cx >= platform.maxX - 2,
           let other = neighborScreen(left: d < 0), other.frame.contains(NSEvent.mouseLocation) {
            cross(to: other, left: d < 0)
            return
        }
        facing = map(d > 0 ? 1 : -1, surface)
        view.mood = .chase
        advance(chaseSpeed * dt, autonomous: false, f)
    }

    /// Move along the surface. When `autonomous`, reaching an end makes a decision
    /// (turn around, climb the wall, hop off a window).
    func advance(_ distance: CGFloat, autonomous: Bool, _ f: NSRect) {
        let s = map(facing, surface)
        let distance = distance * gait
        switch surface {
        case .floor, .ceiling: cx += s * distance
        case .leftWall, .rightWall: cy += s * distance
        case .air: return
        }
        if autonomous { handleEnds(f, s) }
    }

    /// Slows right down through the turn, then picks the pace back up.
    func turnAround() { facing = -facing; gait = min(gait, 0.15) }

    func handleEnds(_ f: NSRect, _ s: CGFloat) {
        let was = surface
        switch surface {
        case .floor:
            if cx <= platform.minX && s < 0 { floorEnd(f, left: true, s) }
            else if cx >= platform.maxX && s > 0 { floorEnd(f, left: false, s) }

        case .ceiling:
            let left = cx <= f.minX + reach && s < 0
            let right = cx >= f.maxX - reach && s > 0
            if left || right {
                if neighborScreen(left: left) != nil {
                    turnAround()                           // another display starts here: no wall to climb down
                } else if Double.random(in: 0..<1) < 0.7 {
                    surface = left ? .leftWall : .rightWall
                    facing = map(-1, surface)              // head down the wall
                    snap(f)
                } else { turnAround() }
            }

        case .leftWall, .rightWall:
            if cy >= f.maxY - reach && s > 0 {
                if Double.random(in: 0..<1) < 0.7 {
                    surface = .ceiling
                    facing = map(was == .leftWall ? 1 : -1, .ceiling)
                    snap(f)
                } else { turnAround() }
            } else if cy <= f.minY + reach && s < 0 {
                surface = .floor
                platform = dock(f)
                facing = map(was == .leftWall ? 1 : -1, .floor)
                snap(f)
            }

        case .air:
            break
        }
    }

    func floorEnd(_ f: NSRect, left: Bool, _ s: CGFloat) {
        if hidePhase == .going {
            hidePhase = .hidden                             // reached the edge: duck behind it
            remaining = .random(in: 6...10)
            return
        }
        if platform.id == 0 {
            if let other = neighborScreen(left: left) {
                // Another display starts here: hop across to explore it, or turn back.
                if forceClimb || Double.random(in: 0..<1) < 0.45 { forceClimb = false; cross(to: other, left: left) }
                else { turnAround() }
            } else if let far = NSScreen.screens.filter({ $0 != currentScreen }).randomElement(), Double.random(in: 0..<1) < 0.15 {
                // No display on this side, but there are others (above, below, further along): leap over now and then.
                cross(to: far, left: far.frame.midX < currentScreen.frame.midX)
            } else if settings.climbEdges && (forceClimb || Double.random(in: 0..<1) < 0.5) {
                forceClimb = false
                surface = left ? .leftWall : .rightWall
                facing = map(1, surface)                    // head up the wall
                snap(f)
                if Double.random(in: 0..<1) < 0.4 { say(Dialogue.clung.randomElement() ?? "Climbing!") }
            } else {
                turnAround()
            }
        } else if Double.random(in: 0..<1) < 0.4 {
            surface = .air                                  // hop off the window edge
            vy = 0
            cx += s * 30
        } else {
            turnAround()
        }
    }
}
