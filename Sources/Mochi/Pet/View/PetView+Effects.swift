#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Sweat, headphones, Zs, music notes and hearts.
extension PetView {
    /// Two drops of sweat sliding down the side of the head.
    func drawSweat(_ body: NSRect) {
        for i in 0..<2 {
            let phase = fmod(time * 0.8 + CGFloat(i) * 0.5, 1)
            let x = body.maxX - 4 + CGFloat(i) * 5
            let y = body.maxY - 6 - phase * 16
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: x, y: y + 6))
            drop.curve(to: NSPoint(x: x, y: y - 3), controlPoint1: NSPoint(x: x + 4.5, y: y), controlPoint2: NSPoint(x: x + 3, y: y - 3))
            drop.curve(to: NSPoint(x: x, y: y + 6), controlPoint1: NSPoint(x: x - 3, y: y - 3), controlPoint2: NSPoint(x: x - 4.5, y: y))
            NSColor(calibratedRed: 0.52, green: 0.78, blue: 1.0, alpha: 1 - phase).setFill(); drop.fill()
            NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1 - phase).setStroke(); drop.lineWidth = 1; drop.stroke()
        }
    }

    // MARK: Accessories & effects

    func drawHeadphones(_ body: NSRect) {
        // The "head" is the whole body, except for the ghost where it is the dome.
        let isGhost = species == .ghost
        let a = body.width / 2 + 3
        // Gumdrop bodies are widest below the middle, so the band's ellipse is centred there.
        let b = (isGhost ? body.width / 2 : body.height * 0.58) + 2
        let c = NSPoint(x: body.midX, y: isGhost ? body.maxY - body.width / 2 : body.minY + body.height * 0.42)

        let band = NSBezierPath()
        var deg: CGFloat = 18
        while deg <= 162 {
            let r = deg * .pi / 180
            let pt = NSPoint(x: c.x + a * cos(r), y: c.y + b * sin(r))
            if deg == 18 { band.move(to: pt) } else { band.line(to: pt) }
            deg += 6
        }
        band.lineWidth = 4
        band.lineCapStyle = .round
        NSColor(calibratedWhite: 0.22, alpha: 1).setStroke()
        band.stroke()

        for deg in [CGFloat(12), 168] {
            let r = deg * .pi / 180
            let p = NSPoint(x: c.x + a * cos(r), y: c.y + b * sin(r))
            let cup = NSBezierPath(roundedRect: NSRect(x: p.x - 4.5, y: p.y - 8, width: 9, height: 16), xRadius: 4, yRadius: 4)
            NSColor(calibratedRed: 0.95, green: 0.36, blue: 0.5, alpha: 1).setFill(); cup.fill()
            NSColor(calibratedRed: 0.3, green: 0.1, blue: 0.18, alpha: 1).setStroke(); cup.lineWidth = 1.5; cup.stroke()
        }
    }

    func drawZs(near body: NSRect) {
        for i in 0..<2 {
            let phase = fmod(time * 0.6 + CGFloat(i) * 0.5, 1)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 14),
                .foregroundColor: NSColor.systemIndigo.withAlphaComponent(1 - phase)
            ]
            ("z" as NSString).draw(at: NSPoint(x: body.maxX - 6 + phase * 10, y: body.maxY - 6 + phase * 16),
                                   withAttributes: attrs)
        }
    }

    func drawNotes(near body: NSRect) {
        for i in 0..<2 {
            let phase = fmod(time * 0.9 + CGFloat(i) * 0.5, 1)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 16),
                .foregroundColor: NSColor.systemPink.withAlphaComponent(1 - phase)
            ]
            let side: CGFloat = i == 0 ? -1 : 1
            ("♪" as NSString).draw(at: NSPoint(x: body.midX + side * (body.width / 2 - 4) + side * phase * 8,
                                               y: body.maxY - 10 + phase * 22), withAttributes: attrs)
        }
    }

    func drawHearts() {
        for h in hearts where h.age >= 0 {
            let alpha = max(0, 1 - h.age / 1.1)
            let s = h.size
            let p = NSBezierPath()
            p.move(to: NSPoint(x: h.x, y: h.y - s * 0.9))
            p.curve(to: NSPoint(x: h.x - s, y: h.y + s * 0.2),
                    controlPoint1: NSPoint(x: h.x - s * 0.4, y: h.y - s * 0.6),
                    controlPoint2: NSPoint(x: h.x - s, y: h.y - s * 0.3))
            p.curve(to: NSPoint(x: h.x, y: h.y + s * 0.35),
                    controlPoint1: NSPoint(x: h.x - s, y: h.y + s * 0.9),
                    controlPoint2: NSPoint(x: h.x - s * 0.2, y: h.y + s * 0.9))
            p.curve(to: NSPoint(x: h.x + s, y: h.y + s * 0.2),
                    controlPoint1: NSPoint(x: h.x + s * 0.2, y: h.y + s * 0.9),
                    controlPoint2: NSPoint(x: h.x + s, y: h.y + s * 0.9))
            p.curve(to: NSPoint(x: h.x, y: h.y - s * 0.9),
                    controlPoint1: NSPoint(x: h.x + s, y: h.y - s * 0.3),
                    controlPoint2: NSPoint(x: h.x + s * 0.4, y: h.y - s * 0.6))
            NSColor(calibratedRed: 1, green: 0.35, blue: 0.5, alpha: alpha).setFill()
            p.fill()
        }
    }
}
