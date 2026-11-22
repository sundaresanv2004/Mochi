#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// A tiny click-through window showing one emoji (treats and toys).
private func emojiWindow(_ emoji: String, at origin: NSPoint) -> NSWindow {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 36, height: 36),
                          styleMask: .borderless, backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.level = .floating
    window.ignoresMouseEvents = true
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    window.animationBehavior = .none
    window.isReleasedWhenClosed = false

    let label = NSTextField(labelWithString: emoji)
    label.font = NSFont.systemFont(ofSize: 26)
    label.alignment = .center
    label.frame = NSRect(x: 0, y: 2, width: 36, height: 32)
    window.contentView = label
    window.setFrameOrigin(origin)
    window.orderFrontRegardless()
    return window
}

/// A snack that drops from the top of the screen for the pet to run to and eat.
final class Treat {
    private let window: NSWindow
    private(set) var x: CGFloat
    private var y: CGFloat
    private var vy: CGFloat = 0
    private(set) var landed = false
    let born = Date()

    init(emoji: String, x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
        window = emojiWindow(emoji, at: NSPoint(x: x - 18, y: y))
    }

    func update(_ dt: CGFloat, floorY: CGFloat) {
        if !landed {
            vy -= 1500 * dt
            y += vy * dt
            if y <= floorY { y = floorY; landed = true }
        }
        window.setFrameOrigin(NSPoint(x: x - 18, y: y))
    }

    func remove() { window.orderOut(nil) }
}

/// A bouncy toy the pet chases along the Dock and kicks back into the air.
final class Ball {
    private let window: NSWindow
    private(set) var x: CGFloat
    private var y: CGFloat
    private var vx: CGFloat
    private var vy: CGFloat = 0
    private var floorY: CGFloat
    private(set) var kicks = 0
    private var lastKick = Date.distantPast
    let born = Date()

    init(emoji: String, x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
        floorY = y
        vx = .random(in: -160...160)
        window = emojiWindow(emoji, at: NSPoint(x: x - 18, y: y))
    }

    /// Height above the floor.
    var height: CGFloat { y - floorY }
    var canKick: Bool { height < 40 && Date().timeIntervalSince(lastKick) > 0.45 }

    func kick(vx: CGFloat, vy: CGFloat) {
        self.vx = vx
        self.vy = vy
        kicks += 1
        lastKick = Date()
    }

    func update(_ dt: CGFloat, floorY: CGFloat, minX: CGFloat, maxX: CGFloat) {
        self.floorY = floorY
        vy -= 1500 * dt
        x += vx * dt
        y += vy * dt
        if y <= floorY {
            y = floorY
            vy = abs(vy) > 90 ? -vy * 0.62 : 0       // bounce, then settle
            vx *= 0.82
            if abs(vx) < 8 { vx = 0 }
        }
        if x < minX { x = minX; vx = abs(vx) * 0.8 }
        if x > maxX { x = maxX; vx = -abs(vx) * 0.8 }
        window.setFrameOrigin(NSPoint(x: x - 18, y: y))
    }

    func remove() { window.orderOut(nil) }
}
