#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Screen geometry, surfaces and the window tops the pet can stand on.
extension PetController {
    /// The area the pet lives in: the screen minus the menu bar and the Dock.
    /// When the Dock's strip is reserved but the Dock isn't there, the pet gets that strip too.
    var screenFrame: NSRect {
        let s = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let v = s.visibleFrame
        guard dockHidden else { return v }
        return NSRect(x: s.frame.minX, y: s.frame.minY, width: s.frame.width, height: v.maxY - s.frame.minY)
    }

    func checkDock() {
        let s = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let v = s.visibleFrame
        let reserved = v.minY - s.frame.minY > 8 || v.minX - s.frame.minX > 8 || s.frame.maxX - v.maxX > 8
        dockHidden = reserved && !WindowScanner.dockIsShowing()
    }
    var hour: Int { Calendar.current.component(.hour, from: Date()) }
    var canAct: Bool { surface != .air && jump == nil && !held }

    func dock(_ f: NSRect) -> Platform {
        Platform(id: 0, minX: f.minX + reach, maxX: f.maxX - reach, top: f.minY)
    }

    func allPlatforms(_ f: NSRect) -> [Platform] {
        [dock(f)] + (settings.walkOnWindows ? windowPlatforms : [])
    }

    /// Local facing ↔ direction along the surface axis (x on floor/ceiling, y on walls).
    /// The mapping is its own inverse.
    func map(_ v: CGFloat, _ s: Surface) -> CGFloat {
        (s == .ceiling || s == .leftWall) ? -v : v
    }

    func angle(for s: Surface) -> CGFloat {
        switch s {
        case .floor, .air: return 0
        case .leftWall: return -.pi / 2
        case .rightWall: return .pi / 2
        case .ceiling: return .pi
        }
    }

    func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), max(lo, hi)) }

    /// Pin the pet to its surface and keep it inside the screen.
    func snap(_ f: NSRect) {
        let r = reach
        switch surface {
        case .floor:
            cx = clamp(cx, platform.minX, platform.maxX)
            cy = platform.top + r
        case .ceiling:
            cx = clamp(cx, f.minX + reach, f.maxX - reach)
            cy = f.maxY - r
        case .leftWall:
            cx = f.minX + r
            cy = clamp(cy, f.minY + reach, f.maxY - reach)
        case .rightWall:
            cx = f.maxX - r
            cy = clamp(cy, f.minY + reach, f.maxY - reach)
        case .air:
            break
        }
    }

    func isOnScreen() -> Bool {
        let p = CGPoint(x: cx, y: cy)
        return NSScreen.screens.contains { $0.frame.insetBy(dx: -20, dy: -20).contains(p) }
    }

    // MARK: Platforms (windows)

    func refreshPlatforms(_ now: Date, _ f: NSRect) {
        // Standing on a window needs quick updates to follow it; otherwise twice a second is plenty.
        let every = (surface == .floor && platform.id != 0) || jump != nil ? 0.25 : 0.5
        guard now.timeIntervalSince(lastScan) > every else { return }
        lastScan = now
        if now < freezeUntil { return }            // Spaces are sliding: keep what we knew
        checkDock()

        let scanned = settings.walkOnWindows ? WindowScanner.platforms(in: f) : []

        if surface == .floor, platform.id != 0, jump == nil {
            if let p = scanned.first(where: { $0.id == platform.id }) {
                missingScans = 0
                let jumped = abs(p.top - platform.top) > 80 || abs(p.minX - platform.minX) > 80
                if jumped, now.timeIntervalSince(lastFreeze) > 2 {
                    // A sudden big move (Space swipe, window snapping): wait for it to settle.
                    lastFreeze = now
                    freezeUntil = now.addingTimeInterval(0.8)
                    return
                }
                platform = p                       // follow the window
            } else {
                missingScans += 1
                if missingScans < 3 { return }     // may be a flicker: only fall if it stays gone
                missingScans = 0
                surface = .air; vy = 0             // window closed or on another Space
            }
        }
        windowPlatforms = scanned
    }

    func reachable(_ p: Platform, feet: CGFloat) -> Bool {
        guard p.id != platform.id, p.top > feet + 30, p.top - feet < 600 else { return false }
        let dx = cx < p.minX ? p.minX - cx : (cx > p.maxX ? cx - p.maxX : 0)
        return dx < 450
    }
}
