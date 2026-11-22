#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Signature power-move effects.
extension PetView {
    /// Where the mouth is, shared by the face and the effects that come out of it.
    func eyeLine(_ body: NSRect) -> CGFloat {
        let v: CGFloat
        switch species {
        case .ghost: v = 0.60
        case .penguin: v = 0.56
        case .dino, .robot: v = 0.74
        case .dragon: v = 0.70
        case .shark: v = 0.66
        case .wolf: v = 0.61
        default: v = 0.50
        }
        return body.minY + body.height * v
    }

    func drawPower(_ body: NSRect) {
        let fx = body.midX + facing * 5
        let mouth = NSPoint(x: fx + facing * 6, y: eyeLine(body) - (species.style == .tough ? 17 : 11))
        switch species {
        case .dragon:
            // a jet of fire, growing and fading as it leaves the mouth
            for i in 0..<5 {
                let ph = fmod(time * 2.4 + CGFloat(i) * 0.2, 1)
                let c = NSPoint(x: mouth.x + facing * (5 + ph * 34), y: mouth.y + sin(ph * 7 + CGFloat(i)) * 3)
                let r = 4.5 + ph * 8
                NSColor(calibratedRed: 1.00, green: 0.45, blue: 0.12, alpha: 1 - ph).setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
                NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.35, alpha: 1 - ph).setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - r * 0.5, y: c.y - r * 0.5, width: r, height: r)).fill()
            }
        case .robot:
            // crackling bolts of electricity
            NSColor(calibratedRed: 1.00, green: 0.86, blue: 0.25, alpha: 1).setStroke()
            for (i, a) in [CGFloat(0.5), 1.4, 2.5, -0.4].enumerated() where Int(time * 12 + CGFloat(i) * 1.7) % 2 == 0 {
                let c = NSPoint(x: body.midX + cos(a) * (body.width / 2 + 9), y: body.midY + sin(a) * (body.height / 2 + 9))
                let z = NSBezierPath()
                z.move(to: NSPoint(x: c.x - 3, y: c.y + 8)); z.line(to: NSPoint(x: c.x + 2, y: c.y + 1))
                z.line(to: NSPoint(x: c.x - 2, y: c.y - 1)); z.line(to: NSPoint(x: c.x + 3, y: c.y - 8))
                z.lineWidth = 2.4; z.lineJoinStyle = .round; z.lineCapStyle = .round; z.stroke()
            }
        case .dino, .ghost, .wolf, .shark:
            // sound waves from a mighty roar (or a very loud "boo")
            for i in 0..<3 {
                let ph = fmod(time * 1.8 + CGFloat(i) / 3, 1)
                let wave = NSBezierPath()
                let mid: CGFloat = facing > 0 ? 0 : 180
                wave.appendArc(withCenter: mouth, radius: 9 + ph * 24, startAngle: mid - 38, endAngle: mid + 38)
                wave.lineWidth = 2.6; wave.lineCapStyle = .round
                species.outline.withAlphaComponent(1 - ph).setStroke(); wave.stroke()
            }
        default:
            // a burst of twinkling stars
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3 + time * 1.5
                let tw = 0.5 + 0.5 * sin(time * 9 + CGFloat(i) * 2)
                let c = NSPoint(x: body.midX + cos(a) * (body.width / 2 + 10), y: body.midY + sin(a) * (body.height / 2 + 8))
                let r = 2.5 + tw * 3.5
                let star = NSBezierPath()
                star.move(to: NSPoint(x: c.x, y: c.y + r))
                for (dx, dy) in [(CGFloat(0.28), CGFloat(0.28)), (1, 0), (0.28, -0.28), (0, -1), (-0.28, -0.28), (-1, 0), (-0.28, 0.28)] {
                    star.line(to: NSPoint(x: c.x + dx * r, y: c.y + dy * r))
                }
                star.close()
                NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.28, alpha: 0.5 + tw * 0.5).setFill(); star.fill()
            }
        }
    }
}
