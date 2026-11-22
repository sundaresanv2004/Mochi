#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Ears, tails, limbs and markings for Mochi, Miso, Clover, Pip and Boo.
extension PetView {
    func drawFeet(_ body: NSRect) {
        var step: CGFloat = (mood == .walk || mood == .chase) ? sin(time * (mood == .chase ? 14 : walkRate)) : 0
        if vibing, mood != .walk { step = sin(beatPhase) * 0.8 }      // tapping its feet to the beat
        let wide: CGFloat = species == .penguin ? 17 : 14
        for (i, dx) in ([-1, 1] as [CGFloat]).enumerated() {
            let up = max(0, i == 0 ? step : -step) * 4
            let r = NSRect(x: body.midX + dx * body.width * 0.21 - wide / 2, y: body.minY - 3 + up, width: wide, height: 8.5)
            let p = NSBezierPath(ovalIn: r)
            species.foot.setFill(); p.fill()
            species.footOutline.setStroke(); p.lineWidth = 2; p.stroke()
        }
    }

    func drawSprout(_ ctx: CGContext, _ body: NSRect) {
        let sway = sin(time * 3) * 0.08
        let green = NSColor(calibratedRed: 0.60, green: 0.86, blue: 0.52, alpha: 1)
        let dark = NSColor(calibratedRed: 0.30, green: 0.54, blue: 0.32, alpha: 1)
        ctx.saveGState()
        ctx.translateBy(x: body.midX + facing * 3, y: body.maxY - 4)
        // little stem
        let stem = NSBezierPath()
        stem.move(to: .zero); stem.line(to: NSPoint(x: 0, y: 7))
        stem.lineWidth = 3.5; stem.lineCapStyle = .round; dark.setStroke(); stem.stroke()
        ctx.translateBy(x: 0, y: 6)
        for (ang, len) in [(CGFloat(0.85), CGFloat(17)), (-0.75, 14)] {
            ctx.saveGState()
            ctx.rotate(by: ang + sway)
            // a pointed leaf with a centre vein
            let leaf = NSBezierPath()
            leaf.move(to: .zero)
            leaf.curve(to: NSPoint(x: 0, y: len), controlPoint1: NSPoint(x: 7, y: len * 0.25), controlPoint2: NSPoint(x: 5.5, y: len * 0.8))
            leaf.curve(to: .zero, controlPoint1: NSPoint(x: -5.5, y: len * 0.8), controlPoint2: NSPoint(x: -7, y: len * 0.25))
            leaf.lineJoinStyle = .round
            green.setFill(); leaf.fill()
            dark.setStroke(); leaf.lineWidth = 1.8; leaf.stroke()
            let vein = NSBezierPath()
            vein.move(to: NSPoint(x: 0, y: 3)); vein.line(to: NSPoint(x: 0, y: len - 5))
            vein.lineWidth = 1; vein.lineCapStyle = .round
            dark.withAlphaComponent(0.6).setStroke(); vein.stroke()
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    func drawCatTail(_ body: NSRect) {
        let dir = -facing
        let base = NSPoint(x: body.midX + dir * (body.width / 2 - 8), y: body.minY + body.height * 0.28)
        let active = mood == .walk || mood == .chase
        let wag = sin(time * (active ? 9 : 3)) * (mood == .sad ? 2 : 9)
        let end = NSPoint(x: base.x + dir * 19 + wag, y: base.y + (mood == .sad ? 14 : 32))
        let c2 = NSPoint(x: base.x + dir * 29 + wag, y: base.y + 17)
        let p = NSBezierPath()
        p.move(to: base)
        p.curve(to: end, controlPoint1: NSPoint(x: base.x + dir * 25, y: base.y + 1), controlPoint2: c2)
        p.lineCapStyle = .round
        p.lineWidth = 11; species.outline.setStroke(); p.stroke()
        p.lineWidth = 6.5; species.fur.setStroke(); p.stroke()
        // cream tip
        let tip = NSBezierPath()
        tip.move(to: NSPoint(x: end.x + (c2.x - end.x) * 0.22, y: end.y + (c2.y - end.y) * 0.22))
        tip.line(to: end)
        tip.lineCapStyle = .round
        tip.lineWidth = 6.5
        NSColor(calibratedRed: 1, green: 0.93, blue: 0.82, alpha: 1).setStroke(); tip.stroke()
    }

    func drawCatEars(_ body: NSRect) {
        let a = body.width / 2
        let droop: CGFloat = mood == .sad ? 5 : 0
        for side in [CGFloat(-1), 1] {
            let p1 = NSPoint(x: body.midX + side * a * 0.93, y: body.minY + body.height * 0.60)
            let p2 = NSPoint(x: body.midX + side * a * 0.16, y: body.maxY - 5)
            let apex = NSPoint(x: body.midX + side * (a * 0.80 + droop), y: body.maxY + 15 - droop)
            func ear(_ p1: NSPoint, _ apex: NSPoint, _ p2: NSPoint) -> NSBezierPath {
                // slightly bowed sides and a rounded tip
                let e = NSBezierPath()
                e.move(to: p1)
                e.curve(to: apex, controlPoint1: NSPoint(x: p1.x + side * 3, y: p1.y + (apex.y - p1.y) * 0.5),
                        controlPoint2: NSPoint(x: apex.x + side * 2, y: apex.y - 4))
                e.curve(to: p2, controlPoint1: NSPoint(x: apex.x - side * 5, y: apex.y - 1),
                        controlPoint2: NSPoint(x: p2.x + side * 6, y: p2.y + 8))
                e.close()
                e.lineJoinStyle = .round
                return e
            }
            let outer = ear(p1, apex, p2)
            species.fur.setFill(); outer.fill()
            species.outline.setStroke(); outer.lineWidth = 2.5; outer.stroke()

            let cx = (p1.x + p2.x + apex.x) / 3, cy = (p1.y + p2.y + apex.y) / 3
            func shrink(_ p: NSPoint) -> NSPoint { NSPoint(x: cx + (p.x - cx) * 0.52, y: cy + (p.y - cy) * 0.52) }
            species.accent.setFill()
            ear(shrink(p1), shrink(apex), shrink(p2)).fill()
        }
    }

    func drawBunnyTail(_ body: NSRect) {
        let dir = -facing
        let c = NSPoint(x: body.midX + dir * (body.width / 2 - 1), y: body.minY + 12)
        // a fluffy pom-pom made of three puffs
        for (dx, dy, r) in [(CGFloat(0), CGFloat(0), CGFloat(8)), (4, 5, 5.5), (4, -4, 5.5)] {
            let p = NSBezierPath(ovalIn: NSRect(x: c.x + dir * dx - r, y: c.y + dy - r, width: r * 2, height: r * 2))
            species.outline.setStroke(); p.lineWidth = 4; p.stroke()
        }
        species.fur.setFill()
        for (dx, dy, r) in [(CGFloat(0), CGFloat(0), CGFloat(8)), (4, 5, 5.5), (4, -4, 5.5)] {
            NSBezierPath(ovalIn: NSRect(x: c.x + dir * dx - r, y: c.y + dy - r, width: r * 2, height: r * 2)).fill()
        }
    }

    func drawBunnyEars(_ ctx: CGContext, _ body: NSRect) {
        for u in [CGFloat(-0.40), 0.40] {
            let outward: CGFloat = u < 0 ? 1 : -1       // CCW is positive rotation: left ear leans left
            var rot = outward * 0.14
            switch mood {
            case .walk, .chase: rot += facing * 0.3 + sin(time * walkRate + u) * 0.08
            case .sleep:        rot = outward * 1.15
            case .happy, .dance: rot += sin(time * 9) * 0.12
            case .held:         rot += outward * 0.4
            case .dizzy:        rot += sin(time * 12 + u) * 0.25
            case .sad:          rot = outward * 0.8
            default:            rot += sin(time * 1.5 + u * 3) * 0.03
            }
            let base = NSPoint(x: body.midX + u * body.width / 2, y: body.maxY - 9)
            ctx.saveGState()
            ctx.translateBy(x: base.x, y: base.y)
            ctx.rotate(by: rot)
            // teardrop: narrow at the head, round and wide near the tip
            func ear(_ wdt: CGFloat, _ len: CGFloat, _ y0: CGFloat) -> NSBezierPath {
                let e = NSBezierPath()
                e.move(to: NSPoint(x: 0, y: y0))
                e.curve(to: NSPoint(x: 0, y: len), controlPoint1: NSPoint(x: wdt * 0.55, y: y0 + (len - y0) * 0.2),
                        controlPoint2: NSPoint(x: wdt * 1.15, y: len))
                e.curve(to: NSPoint(x: 0, y: y0), controlPoint1: NSPoint(x: -wdt * 1.15, y: len),
                        controlPoint2: NSPoint(x: -wdt * 0.55, y: y0 + (len - y0) * 0.2))
                e.close()
                return e
            }
            let outer = ear(9, 42, 0)
            species.fur.setFill(); outer.fill()
            species.outline.setStroke(); outer.lineWidth = 2.5; outer.stroke()
            species.accent.setFill()
            ear(4.6, 35, 10).fill()
            ctx.restoreGState()
        }
    }

    /// A little pink bow by the bunny's ear.
    func drawBow(_ ctx: CGContext, _ body: NSRect) {
        let pink = NSColor(calibratedRed: 1.00, green: 0.56, blue: 0.70, alpha: 1)
        let line = NSColor(calibratedRed: 0.72, green: 0.30, blue: 0.45, alpha: 1)
        ctx.saveGState()
        ctx.translateBy(x: body.midX + facing * body.width * 0.27, y: body.maxY - 5)
        ctx.rotate(by: -facing * 0.3)
        for side in [CGFloat(-1), 1] {
            let wing = NSBezierPath()
            wing.move(to: .zero)
            wing.curve(to: NSPoint(x: side * 10, y: 0), controlPoint1: NSPoint(x: side * 4, y: 8), controlPoint2: NSPoint(x: side * 11, y: 8))
            wing.curve(to: .zero, controlPoint1: NSPoint(x: side * 11, y: -8), controlPoint2: NSPoint(x: side * 4, y: -8))
            wing.lineJoinStyle = .round
            pink.setFill(); wing.fill()
            line.setStroke(); wing.lineWidth = 1.5; wing.stroke()
        }
        let knot = NSBezierPath(ovalIn: NSRect(x: -3, y: -3, width: 6, height: 6))
        pink.setFill(); knot.fill()
        line.setStroke(); knot.lineWidth = 1.5; knot.stroke()
        ctx.restoreGState()
    }

    /// Three wispy feathers on top of the penguin's head.
    func drawPenguinTuft(_ body: NSRect) {
        let base = NSPoint(x: body.midX + facing * 2, y: body.maxY - 3)
        let wob = sin(time * 3) * 0.06
        for a in [CGFloat(-0.55), 0, 0.55] {
            let ang = a + wob + .pi / 2
            let len: CGFloat = a == 0 ? 11 : 8
            let tip = NSPoint(x: base.x + cos(ang) * len, y: base.y + sin(ang) * len)
            let p = NSBezierPath()
            p.move(to: base); p.line(to: tip)
            p.lineCapStyle = .round
            p.lineWidth = 6.5; species.outline.setStroke(); p.stroke()
            p.lineWidth = 2.5; species.fur.setStroke(); p.stroke()
        }
    }

    /// A limb that hangs from `pivot` and swings by `ang` (positive = counter-clockwise).
    func drawLimb(_ ctx: CGContext, pivot: NSPoint, size: NSSize, ang: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.rotate(by: ang)
        let p = NSBezierPath(ovalIn: NSRect(x: -size.width / 2, y: -size.height, width: size.width, height: size.height))
        species.fur.setFill(); p.fill()
        species.outline.setStroke(); p.lineWidth = 2.2; p.stroke()
        ctx.restoreGState()
    }

    func drawFlippers(_ ctx: CGContext, _ body: NSRect) {
        for side in [CGFloat(-1), 1] {
            var ang = side * 0.3
            switch mood {
            case .walk, .chase: ang += sin(time * walkRate + (side < 0 ? 0 : .pi)) * 0.28
            case .happy, .dance, .jump, .power: ang = side * (2.2 + sin(time * 14) * 0.35)
            case .stretch: ang = side * 2.6
            case .held: ang = side * (2.0 + sin(time * 20) * 0.4)
            case .sleep: ang = side * 0.12
            case .dizzy: ang = side * (1.0 + sin(time * 12) * 0.3)
            case .idle where vibing: ang = side * (0.5 + abs(sin(beatPhase)) * 0.45)    // flapping to the beat
            case .idle: ang += sin(time * 2 + side) * 0.04
            case .sad: ang = side * 0.1
            }
            let pivot = NSPoint(x: body.midX + side * (body.width / 2 - 3), y: body.minY + body.height * 0.56)
            drawLimb(ctx, pivot: pivot, size: NSSize(width: 12, height: 26), ang: ang)
        }
    }

    func drawGhostArms(_ ctx: CGContext, _ body: NSRect) {
        for side in [CGFloat(-1), 1] {
            var ang = side * 0.95
            switch mood {
            case .happy, .dance, .jump: ang = side * (2.2 + sin(time * 12) * 0.35)
            case .stretch: ang = side * 2.6
            case .held: ang = side * (2.0 + sin(time * 20) * 0.4)
            case .dizzy: ang = side * (1.2 + sin(time * 12) * 0.4)
            case .walk, .chase: ang += sin(time * 8 + side) * 0.2
            case .idle where vibing: ang = side * (1.1 + sin(beatPhase + side) * 0.35)     // waving along
            default: ang += sin(time * 2.4 + side) * 0.1
            }
            let pivot = NSPoint(x: body.midX + side * (body.width / 2 - 2), y: body.minY + body.height * 0.42)
            drawLimb(ctx, pivot: pivot, size: NSSize(width: 9, height: 18), ang: ang)
        }
    }

    func drawPenguinMarkings(_ body: NSRect) {
        NSColor(calibratedRed: 0.99, green: 0.99, blue: 1.0, alpha: 1).setFill()
        let eyeY = body.minY + body.height * 0.56
        let fx = body.midX + facing * 5
        let r = body.width * 0.225
        // heart-shaped face: a round patch around each eye, joined to the belly
        for side in [CGFloat(-1), 1] {
            NSBezierPath(ovalIn: NSRect(x: fx + side * 10 - r, y: eyeY - 2 - r, width: r * 2, height: r * 2)).fill()
        }
        NSBezierPath(ovalIn: NSRect(x: body.midX + facing * 2 - body.width * 0.34, y: body.minY - body.height * 0.02,
                                    width: body.width * 0.68, height: body.height * 0.60)).fill()
    }

    func drawScarf(_ ctx: CGContext, _ body: NSRect) {
        let red = NSColor(calibratedRed: 0.92, green: 0.30, blue: 0.34, alpha: 1)
        let y = body.minY + body.height * 0.27
        let band = NSBezierPath(roundedRect: NSRect(x: body.midX - body.width * 0.40, y: y, width: body.width * 0.80, height: 9),
                                xRadius: 4.5, yRadius: 4.5)
        red.setFill(); band.fill()
        species.outline.setStroke(); band.lineWidth = 1.8; band.stroke()
        // the dangling end sits on the back side
        let tailX = body.midX - facing * (body.width * 0.30)
        let tail = NSBezierPath(roundedRect: NSRect(x: tailX - 4, y: y - 9, width: 8, height: 13), xRadius: 2, yRadius: 2)
        red.setFill(); tail.fill()
        species.outline.setStroke(); tail.lineWidth = 1.6; tail.stroke()
    }
}
