#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// More than one display: the pet lives on one screen at a time and hops across where two screens touch.
extension PetController {
    var currentScreen: NSScreen { window.screen ?? NSScreen.main ?? NSScreen.screens[0] }

    /// The display touching this one's left or right edge, if any (with enough overlap to hop across).
    func neighborScreen(left: Bool) -> NSScreen? {
        let s = currentScreen
        return NSScreen.screens.first { o in
            guard o != s else { return false }
            let touching = left ? abs(o.frame.maxX - s.frame.minX) < 2 : abs(o.frame.minX - s.frame.maxX) < 2
            return touching && o.frame.maxY > s.frame.minY + 100 && o.frame.minY < s.frame.maxY - 100
        }
    }

    /// Leap onto another display, landing on its Dock / bottom edge just inside the side it came in from.
    func cross(to screen: NSScreen, left: Bool) {
        let v = screen.visibleFrame
        let p = Platform(id: 0, minX: v.minX + reach, maxX: v.maxX - reach, top: v.minY)
        let end = CGPoint(x: left ? p.maxX - 30 * scale : p.minX + 30 * scale, y: p.top + reach)
        let start = CGPoint(x: cx, y: cy)
        let dist = hypot(end.x - start.x, end.y - start.y)
        facing = end.x >= start.x ? 1 : -1
        social = .none
        hidePhase = .none
        jump = Jump(start: start, end: end, t: 0, duration: max(0.6, min(1.5, dist / 1100 + 0.45)),
                    height: max(70, end.y - start.y + 60), target: p)
        surface = .air
        if Double.random(in: 0..<1) < 0.5 { say(Dialogue.newScreen.randomElement() ?? "New screen!") }
    }

    /// Head for the display the other pet is on.
    func crossToward(_ b: PetController) {
        guard canAct, action != .sleep else { return }
        let target = b.currentScreen
        cross(to: target, left: target.frame.midX < currentScreen.frame.midX)
    }

    /// Debug page: go to the next display, whichever it is.
    func crossToNextScreen() {
        let all = NSScreen.screens
        guard all.count > 1, canAct, let i = all.firstIndex(of: currentScreen) else { return }
        let target = all[(i + 1) % all.count]
        if action == .sleep { action = .idle }
        cross(to: target, left: target.frame.midX < currentScreen.frame.midX)
    }
}
