#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Eyes, cheeks, mouths and eyewear, plus small drawing helpers.
extension PetView {
    func drawFace(_ body: NSRect) {
        if hidesFace { return }                 // turned around, giving you some privacy
        let sp = species
        if sp.style == .tough { drawToughFace(body); return }
        let ink = sp.ink
        let eyeY = eyeLine(body)
        let spread: CGFloat
        switch sp {
        case .dino, .dragon, .robot, .wolf, .shark: spread = 12.5
        case .mochi: spread = 13.5
        case .cat: spread = 12.5
        case .bunny: spread = 11.5
        case .penguin: spread = 10
        case .ghost: spread = 11.5
        }
        let fx = body.midX + facing * (sp == .mochi ? 6 : 5)
        let blinking = fmod(time + 1.3, 4.3) < 0.12
        let sad = mood == .sad
        let open = mood == .happy || mood == .held || mood == .stretch || mood == .dance || mood == .power
        let cream = NSColor(calibratedRed: 1, green: 0.93, blue: 0.82, alpha: 1)

        // Cat muzzle sits under everything else on the face
        if sp == .cat {
            cream.setFill()
            NSBezierPath(ovalIn: NSRect(x: fx - 13, y: eyeY - 17, width: 26, height: 15)).fill()
        }

        // Rosy cheeks
        sp.accent.withAlphaComponent(mood == .happy || mood == .dance || lostInMusic ? 0.85 : 0.6).setFill()
        for dx in [CGFloat(-1), 1] {
            NSBezierPath(ovalIn: NSRect(x: fx + dx * (spread + 8) - 5.5, y: eyeY - 10.5, width: 11, height: 6.5)).fill()
        }

        // Eyes
        ink.setFill(); ink.setStroke()
        for dx in [CGFloat(-1), 1] {
            let ex = fx + dx * spread
            switch lostInMusic ? .happy : mood {     // eyes closed, enjoying the song
            case .sleep, .stretch:
                arc(NSPoint(x: ex, y: eyeY + 2), 4.6, 200, 340, width: 2.3)
            case .happy, .dance:
                arc(NSPoint(x: ex, y: eyeY - 2.5), 5, 15, 165, width: 2.5)
            case .dizzy:
                spiral(NSPoint(x: ex, y: eyeY), 6)
            case .power:
                // scrunched shut with effort:  >  <
                let squint = NSBezierPath()
                squint.move(to: NSPoint(x: ex - dx * 4.5, y: eyeY + 4.5))
                squint.line(to: NSPoint(x: ex + dx * 3, y: eyeY))
                squint.line(to: NSPoint(x: ex - dx * 4.5, y: eyeY - 4.5))
                squint.lineWidth = 2.5; squint.lineCapStyle = .round; squint.lineJoinStyle = .round; squint.stroke()
            default:
                let wide = mood == .held
                let ew: CGFloat = wide ? 9.5 : 8.4
                let eh: CGFloat = blinking ? 1.7 : (wide ? 12.5 : 11)
                let gx = wide ? 0 : (sad ? 0 : gaze.x), gy = wide ? 0 : (sad ? -1.5 : gaze.y)
                let r = NSRect(x: ex - ew / 2 + gx, y: eyeY - eh / 2 + gy, width: ew, height: eh)
                NSBezierPath(ovalIn: r).fill()
                if !blinking {
                    // two catchlights make the eyes sparkle
                    NSColor.white.setFill()
                    NSBezierPath(ovalIn: NSRect(x: r.midX - 0.6, y: r.midY + 0.6, width: 3.7, height: 3.7)).fill()
                    NSBezierPath(ovalIn: NSRect(x: r.midX - 3.1, y: r.midY - 4, width: 1.9, height: 1.9)).fill()
                    ink.setFill()
                }
                if sad {
                    // worried brows, higher towards the middle
                    let brow = NSBezierPath()
                    brow.move(to: NSPoint(x: ex - dx * 4.5, y: eyeY + 12))
                    brow.line(to: NSPoint(x: ex + dx * 5, y: eyeY + 8.5))
                    brow.lineWidth = 1.9; brow.lineCapStyle = .round; brow.stroke()
                }
            }
        }

        drawEyewear(fx: fx, spread: spread, eyeY: eyeY)

        // Mouth / beak, tucked in close under the eyes
        ink.setFill(); ink.setStroke()
        switch sp {
        case .mochi:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 9.5), 7.5, 8) }
            else if sad { arc(NSPoint(x: fx, y: eyeY - 11.5), 3, 25, 155) }
            else { kittyMouth(NSPoint(x: fx, y: eyeY - 4.5), 2.5) }
        case .cat:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 12.5), 7, 6.5) }
            else { kittyMouth(NSPoint(x: fx, y: eyeY - 8), 2.7) }
            // nose: a tiny rounded heart-ish triangle
            NSColor(calibratedRed: 1, green: 0.52, blue: 0.60, alpha: 1).setFill()
            let nose = NSBezierPath()
            nose.move(to: NSPoint(x: fx - 3, y: eyeY - 3.5)); nose.line(to: NSPoint(x: fx + 3, y: eyeY - 3.5))
            nose.line(to: NSPoint(x: fx, y: eyeY - 7)); nose.close()
            nose.lineJoinStyle = .round; nose.fill()
            NSColor(calibratedRed: 1, green: 0.52, blue: 0.60, alpha: 1).setStroke(); nose.lineWidth = 1.2; nose.stroke()
            // whiskers
            NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.2, alpha: 0.65).setStroke()
            for side in [CGFloat(-1), 1] {
                for k in [CGFloat(-1), 1] {
                    let p = NSBezierPath()
                    p.move(to: NSPoint(x: fx + side * 19, y: eyeY - 9 + k * 1.8))
                    p.line(to: NSPoint(x: fx + side * 30, y: eyeY - 9 + k * 4.5))
                    p.lineWidth = 1.2; p.lineCapStyle = .round; p.stroke()
                }
            }
            // forehead stripes
            NSColor(calibratedRed: 0.86, green: 0.50, blue: 0.20, alpha: 0.9).setStroke()
            for (i, dx) in [CGFloat(-5.5), 0, 5.5].enumerated() {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: fx + dx, y: body.maxY - 3))
                p.line(to: NSPoint(x: fx + dx, y: body.maxY - (i == 1 ? 11 : 8)))
                p.lineWidth = 2.2; p.lineCapStyle = .round; p.stroke()
            }
        case .bunny:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 12.5), 6.5, 6.5) }
            else {
                kittyMouth(NSPoint(x: fx, y: eyeY - 8), 2.5)
                // little teeth
                NSColor.white.setFill()
                let teeth = NSBezierPath(roundedRect: NSRect(x: fx - 2.5, y: eyeY - 14, width: 5, height: 4.2), xRadius: 1.2, yRadius: 1.2)
                teeth.fill()
                ink.setStroke(); teeth.lineWidth = 0.9; teeth.stroke()
                let gap = NSBezierPath()
                gap.move(to: NSPoint(x: fx, y: eyeY - 10)); gap.line(to: NSPoint(x: fx, y: eyeY - 13.6))
                gap.lineWidth = 0.8; gap.stroke()
            }
            sp.accent.blended(withFraction: 0.35, of: .systemPink)?.setFill()
            NSBezierPath(ovalIn: NSRect(x: fx - 3, y: eyeY - 7, width: 6, height: 4.4)).fill()
        case .penguin:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 11), 7, 6) }
            // a small rounded beak
            let top = eyeY - (open ? 2 : 3)
            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: fx - 5.5, y: top))
            beak.curve(to: NSPoint(x: fx + 5.5, y: top), controlPoint1: NSPoint(x: fx - 3, y: top + 3), controlPoint2: NSPoint(x: fx + 3, y: top + 3))
            beak.curve(to: NSPoint(x: fx, y: top - 6.5), controlPoint1: NSPoint(x: fx + 5, y: top - 3), controlPoint2: NSPoint(x: fx + 2.5, y: top - 6.5))
            beak.curve(to: NSPoint(x: fx - 5.5, y: top), controlPoint1: NSPoint(x: fx - 2.5, y: top - 6.5), controlPoint2: NSPoint(x: fx - 5, y: top - 3))
            beak.lineJoinStyle = .round
            sp.foot.setFill(); beak.fill()
            sp.footOutline.setStroke(); beak.lineWidth = 1.5; beak.stroke()
        case .ghost:
            if open { openMouth(NSPoint(x: fx, y: eyeY - 11), 8, 9) }
            else if sad { arc(NSPoint(x: fx, y: eyeY - 12.5), 3, 25, 155) }
            else { arc(NSPoint(x: fx, y: eyeY - 5.5), 3, 205, 335) }
        case .dino, .dragon, .robot, .wolf, .shark:
            break       // drawn by drawToughFace
        }
    }

    /// Shades and glasses sit over the eyes, so they are drawn with the face.
    func drawEyewear(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        // Watching a film: 3D glasses go on over anything else.
        // 3D glasses for a film go on over anything else; tears and the screen's reflection go with the eyes.
        if drawActEyes(fx: fx, spread: spread, eyeY: eyeY) { return }
        if outfit == .shades {
            let dark = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.14, alpha: 1)
            for dx in [CGFloat(-1), 1] {
                let lens = NSBezierPath(roundedRect: NSRect(x: fx + dx * spread - 8.5, y: eyeY - 6, width: 17, height: 12), xRadius: 4.5, yRadius: 4.5)
                dark.setFill(); lens.fill()
                NSColor.white.withAlphaComponent(0.55).setStroke()
                let shine = NSBezierPath()
                shine.move(to: NSPoint(x: fx + dx * spread - 4.5, y: eyeY + 3)); shine.line(to: NSPoint(x: fx + dx * spread - 1, y: eyeY + 3.6))
                shine.lineWidth = 1.5; shine.lineCapStyle = .round; shine.stroke()
            }
            let bar = NSBezierPath()
            bar.move(to: NSPoint(x: fx - spread + 6, y: eyeY + 3.5)); bar.line(to: NSPoint(x: fx + spread - 6, y: eyeY + 3.5))
            bar.lineWidth = 2.4; dark.setStroke(); bar.stroke()
        }
        if outfit == .glasses {
            let frame = NSColor(calibratedRed: 0.24, green: 0.20, blue: 0.30, alpha: 1)
            for dx in [CGFloat(-1), 1] {
                let lens = NSBezierPath(ovalIn: NSRect(x: fx + dx * spread - 8, y: eyeY - 8, width: 16, height: 16))
                NSColor.white.withAlphaComponent(0.18).setFill(); lens.fill()
                frame.setStroke(); lens.lineWidth = 1.7; lens.stroke()
            }
            let bridge = NSBezierPath()
            bridge.move(to: NSPoint(x: fx - spread + 8, y: eyeY + 1))
            bridge.curve(to: NSPoint(x: fx + spread - 8, y: eyeY + 1),
                         controlPoint1: NSPoint(x: fx - 2, y: eyeY + 3.5), controlPoint2: NSPoint(x: fx + 2, y: eyeY + 3.5))
            bridge.lineWidth = 1.7; frame.setStroke(); bridge.stroke()
        }
    }

    /// The classic "ω" mouth: two little arcs side by side.
    func kittyMouth(_ c: NSPoint, _ r: CGFloat) {
        arc(NSPoint(x: c.x - r, y: c.y), r, 195, 345)
        arc(NSPoint(x: c.x + r, y: c.y), r, 195, 345)
    }

    /// An open, happy mouth with a pink tongue inside.
    func openMouth(_ c: NSPoint, _ w: CGFloat, _ h: CGFloat) {
        let r = NSRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        let m = NSBezierPath(ovalIn: r)
        species.ink.setFill(); m.fill()
        NSGraphicsContext.saveGraphicsState()
        m.addClip()
        NSColor(calibratedRed: 1, green: 0.50, blue: 0.56, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: r.minX + w * 0.1, y: r.minY - h * 0.45, width: w * 0.8, height: h * 0.9)).fill()
        NSGraphicsContext.restoreGraphicsState()
        species.ink.setFill()
    }

    func spiral(_ c: NSPoint, _ r: CGFloat) {
        let turns: CGFloat = 2.2
        let total = turns * 2 * .pi
        let p = NSBezierPath()
        var a: CGFloat = 0
        var first = true
        while a <= total {
            let rr = r * a / total
            let ang = a + time * 8
            let pt = NSPoint(x: c.x + cos(ang) * rr, y: c.y + sin(ang) * rr)
            if first { p.move(to: pt); first = false } else { p.line(to: pt) }
            a += 0.4
        }
        p.lineWidth = 1.4
        p.lineCapStyle = .round
        p.stroke()
    }

    func arc(_ center: NSPoint, _ radius: CGFloat, _ start: CGFloat, _ end: CGFloat, width: CGFloat = 2) {
        let p = NSBezierPath()
        p.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
        p.lineWidth = width
        p.lineCapStyle = .round
        p.stroke()
    }
}
