#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Things worn on the head.
extension PetView {
    /// Things worn on the head (glasses are drawn with the face, where the eye positions are known).
    func drawOutfit(_ ctx: CGContext, _ body: NSRect) {
        let top = NSPoint(x: body.midX + facing * 2, y: body.maxY)
        let line = NSColor(calibratedRed: 0.36, green: 0.26, blue: 0.30, alpha: 1)
        switch outfit {
        case .none, .glasses, .shades:
            break

        case .cap:
            // a baseball cap with the brim pointing where the pet looks
            let blue = NSColor(calibratedRed: 0.26, green: 0.52, blue: 0.96, alpha: 1)
            let navy = NSColor(calibratedRed: 0.12, green: 0.24, blue: 0.56, alpha: 1)
            let y = body.maxY - 7
            let brim = NSBezierPath(roundedRect: NSRect(x: facing > 0 ? top.x + 2 : top.x - 26, y: y - 1, width: 24, height: 6), xRadius: 3, yRadius: 3)
            navy.setFill(); brim.fill()
            let dome = NSBezierPath()
            dome.move(to: NSPoint(x: top.x - 15, y: y))
            dome.curve(to: NSPoint(x: top.x + 15, y: y), controlPoint1: NSPoint(x: top.x - 14, y: y + 18), controlPoint2: NSPoint(x: top.x + 14, y: y + 18))
            dome.close(); dome.lineJoinStyle = .round
            blue.setFill(); dome.fill()
            navy.setStroke(); dome.lineWidth = 1.8; dome.stroke()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: top.x - 2, y: y + 12, width: 4, height: 4)).fill()

        case .headband:
            // a ninja headband, knotted at the back with two tails in the wind
            let red = NSColor(calibratedRed: 0.90, green: 0.22, blue: 0.26, alpha: 1)
            let dark = NSColor(calibratedRed: 0.55, green: 0.10, blue: 0.14, alpha: 1)
            let y = body.maxY - body.height * 0.20
            let back = NSPoint(x: body.midX - facing * (body.width / 2 - 5), y: y + 3)
            for (i, dy) in [CGFloat(5), -3].enumerated() {
                let flutter = sin(time * 7 + CGFloat(i) * 1.5) * 3
                let tail = NSBezierPath()
                tail.move(to: back)
                tail.curve(to: NSPoint(x: back.x - facing * 17, y: back.y + dy + flutter),
                           controlPoint1: NSPoint(x: back.x - facing * 6, y: back.y + dy), controlPoint2: NSPoint(x: back.x - facing * 11, y: back.y + dy - flutter))
                tail.lineCapStyle = .round
                tail.lineWidth = 6; dark.setStroke(); tail.stroke()
                tail.lineWidth = 3.4; red.setStroke(); tail.stroke()
            }
            NSGraphicsContext.saveGraphicsState()
            bodyPath(body).addClip()
            let band = NSBezierPath(rect: NSRect(x: body.minX - 2, y: y, width: body.width + 4, height: 7))
            red.setFill(); band.fill()
            dark.setStroke(); band.lineWidth = 1.6; band.stroke()
            NSGraphicsContext.restoreGraphicsState()

        case .flower:
            // tucked behind one ear, on the side away from where the pet is looking
            let c = NSPoint(x: body.midX - facing * body.width * 0.30, y: body.maxY - body.height * 0.13)
            let petal = NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.76, alpha: 1)
            for i in 0..<5 {
                let a = CGFloat(i) * 2 * .pi / 5 + .pi / 2
                let r = NSRect(x: c.x + cos(a) * 4.6 - 3.8, y: c.y + sin(a) * 4.6 - 3.8, width: 7.6, height: 7.6)
                let p = NSBezierPath(ovalIn: r)
                petal.setFill(); p.fill()
                NSColor(calibratedRed: 0.80, green: 0.36, blue: 0.52, alpha: 1).setStroke(); p.lineWidth = 1; p.stroke()
            }
            NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.30, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - 2.8, y: c.y - 2.8, width: 5.6, height: 5.6)).fill()

        case .partyHat:
            ctx.saveGState()
            ctx.translateBy(x: top.x, y: top.y - 4)
            ctx.rotate(by: -facing * 0.16)
            let cone = NSBezierPath()
            cone.move(to: NSPoint(x: -10, y: 0)); cone.line(to: NSPoint(x: 0, y: 23)); cone.line(to: NSPoint(x: 10, y: 0))
            cone.close(); cone.lineJoinStyle = .round
            NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.68, alpha: 1).setFill(); cone.fill()
            NSGraphicsContext.saveGraphicsState()
            cone.addClip()
            NSColor(calibratedRed: 1.00, green: 0.86, blue: 0.36, alpha: 1).setStroke()
            for y in [CGFloat(5), 12, 19] {
                let stripe = NSBezierPath()
                stripe.move(to: NSPoint(x: -12, y: y - 3)); stripe.line(to: NSPoint(x: 12, y: y + 2))
                stripe.lineWidth = 2.6; stripe.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
            line.setStroke(); cone.lineWidth = 1.8; cone.stroke()
            let pom = NSBezierPath(ovalIn: NSRect(x: -4, y: 20, width: 8, height: 8))
            NSColor.white.setFill(); pom.fill()
            line.setStroke(); pom.lineWidth = 1.5; pom.stroke()
            ctx.restoreGState()

        case .crown:
            ctx.saveGState()
            ctx.translateBy(x: top.x, y: top.y - 3)
            ctx.rotate(by: -facing * 0.08)
            let crown = NSBezierPath()
            crown.move(to: NSPoint(x: -12, y: 0))
            for (x, y) in [(CGFloat(-13), CGFloat(13)), (-6.5, 6), (0, 15), (6.5, 6), (13, 13), (12, 0)] {
                crown.line(to: NSPoint(x: x, y: y))
            }
            crown.close(); crown.lineJoinStyle = .round
            NSColor(calibratedRed: 1.00, green: 0.82, blue: 0.30, alpha: 1).setFill(); crown.fill()
            NSColor(calibratedRed: 0.74, green: 0.50, blue: 0.10, alpha: 1).setStroke(); crown.lineWidth = 1.8; crown.stroke()
            for (x, c) in [(CGFloat(-6.5), NSColor.systemTeal), (0, NSColor.systemPink), (6.5, NSColor.systemTeal)] {
                c.setFill()
                NSBezierPath(ovalIn: NSRect(x: x - 1.8, y: 1.6, width: 3.6, height: 3.6)).fill()
            }
            ctx.restoreGState()

        case .halo:
            let bob = sin(time * 2.2) * 1.5
            let ring = NSBezierPath(ovalIn: NSRect(x: top.x - 14, y: top.y + 7 + bob, width: 28, height: 8))
            ring.lineWidth = 4.5
            NSColor(calibratedRed: 0.80, green: 0.60, blue: 0.14, alpha: 0.9).setStroke(); ring.stroke()
            ring.lineWidth = 2.6
            NSColor(calibratedRed: 1.00, green: 0.90, blue: 0.45, alpha: 1).setStroke(); ring.stroke()
        }
    }
}
