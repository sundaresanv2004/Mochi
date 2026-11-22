#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Films and shows: 3D cinema, blanket burrito, soda and nachos, scary scene, tearjerker. The pet is quiet
/// and still during a film (see the brain), so these are cosy, slow acts; the screen's glow is on them all.
extension PetView {
    // MARK: 3D cinema

    /// Red and blue cardboard 3D glasses, in place of whatever eyewear the pet has on.
    func draw3DGlasses(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        let bar = roundRect(NSRect(x: fx - spread - 10, y: eyeY - 7.5, width: spread * 2 + 20, height: 15), 4)
        paint(bar, NSColor(calibratedWhite: 0.97, alpha: 1), NSColor(calibratedWhite: 0.35, alpha: 1), 1.3)
        // Red on the left, blue on the right, as seen by the viewer.
        for (dx, colour) in [(CGFloat(-1), rgb(0.93, 0.18, 0.24, 0.9)), (1, rgb(0.10, 0.72, 0.95, 0.9))] {
            paint(roundRect(NSRect(x: fx + dx * spread - 7.5, y: eyeY - 5, width: 15, height: 10), 3), colour)
            let shine = NSBezierPath()
            shine.move(to: NSPoint(x: fx + dx * spread - 4.5, y: eyeY + 2.2)); shine.line(to: NSPoint(x: fx + dx * spread - 1.5, y: eyeY + 2.8))
            shine.lineWidth = 1.2; shine.lineCapStyle = .round; NSColor.white.withAlphaComponent(0.6).setStroke(); shine.stroke()
        }
    }

    /// A striped bucket of popcorn held in front, and every few seconds a piece on its way to the mouth.
    func drawPopcorn(_ body: NSRect) {
        let w: CGFloat = 17, h: CGFloat = 18
        let x = body.midX + facing * (body.width / 2 - 10) - w / 2
        let y = body.minY + 1
        let cream = rgb(1.0, 0.96, 0.80), butter = rgb(0.93, 0.78, 0.40)
        for (dx, dy, r) in [(CGFloat(2.5), CGFloat(h - 1), CGFloat(3.6)), (7.5, h + 1.5, 4), (12.5, h - 0.5, 3.6), (5, h + 4, 3.2), (10.5, h + 4.5, 3.2)] {
            paint(circle(NSPoint(x: x + dx, y: y + dy), r), cream, butter, 0.8)
        }
        let bucket = NSBezierPath()
        bucket.move(to: NSPoint(x: x, y: y + h)); bucket.line(to: NSPoint(x: x + w, y: y + h))
        bucket.line(to: NSPoint(x: x + w - 2.5, y: y)); bucket.line(to: NSPoint(x: x + 2.5, y: y)); bucket.close()
        paint(bucket, .white)
        NSGraphicsContext.saveGraphicsState(); bucket.addClip()
        for i in stride(from: 0, to: 4, by: 2) { paint(NSBezierPath(rect: NSRect(x: x + CGFloat(i) * w / 4 + 1, y: y, width: w / 4, height: h)), rgb(0.88, 0.17, 0.20)) }
        NSGraphicsContext.restoreGraphicsState()
        paint(bucket, nil, rgb(0.45, 0.08, 0.10), 1.2)

        if let t = moment(every: 4.2, lasting: 0.7) {
            let from = NSPoint(x: x + w / 2, y: y + h + 3), to = mouthPoint(body)
            let p = NSPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t + sin(t * .pi) * 14)
            paint(circle(p, 2.6), cream, butter, 0.8)
        }
    }

    // MARK: Blanket burrito

    /// Tucked up to the chin in a plaid blanket, paws holding the edge.
    func drawBlanket(_ body: NSRect) {
        let top = mouthPoint(body).y - 4
        let wrap = bodyPath(body.insetBy(dx: -3.5, dy: -3))
        NSGraphicsContext.saveGraphicsState()
        wrap.addClip()
        NSBezierPath(rect: NSRect(x: body.minX - 6, y: body.minY - 6, width: body.width + 12, height: top - body.minY + 6)).addClip()
        paint(NSBezierPath(rect: body.insetBy(dx: -8, dy: -8)), rgb(0.80, 0.33, 0.30))
        // Plaid: broad darker bands, thin cream lines, both ways.
        for y in stride(from: body.minY - 4, to: top, by: 9) { paint(NSBezierPath(rect: NSRect(x: body.minX - 8, y: y, width: body.width + 16, height: 3.5)), rgb(0.60, 0.20, 0.22, 0.75)) }
        for x in stride(from: body.minX - 4, to: body.maxX + 4, by: 9) { paint(NSBezierPath(rect: NSRect(x: x, y: body.minY - 8, width: 3.5, height: top - body.minY + 10)), rgb(0.60, 0.20, 0.22, 0.5)) }
        for x in stride(from: body.minX + 1, to: body.maxX + 4, by: 9) { paint(NSBezierPath(rect: NSRect(x: x, y: body.minY - 8, width: 0.9, height: top - body.minY + 10)), rgb(1, 0.92, 0.75, 0.8)) }
        // A soft shadow under the folded hem.
        paint(NSBezierPath(rect: NSRect(x: body.minX - 6, y: top - 6, width: body.width + 12, height: 2.5)), rgb(0.35, 0.1, 0.1, 0.25))
        NSGraphicsContext.restoreGraphicsState()

        // The folded hem across the top, slightly wavy, and the outline around the wrap.
        NSGraphicsContext.saveGraphicsState(); wrap.addClip()
        let hem = NSBezierPath()
        hem.move(to: NSPoint(x: body.minX - 6, y: top - 3.5))
        var x = body.minX - 6
        while x <= body.maxX + 6 { x += 3; hem.line(to: NSPoint(x: x, y: top - 3.5 + sin(x * 0.5) * 0.7)) }
        hem.line(to: NSPoint(x: body.maxX + 6, y: top + 1)); hem.line(to: NSPoint(x: body.minX - 6, y: top + 1)); hem.close()
        paint(hem, rgb(0.98, 0.88, 0.72))
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: body.minX - 8, y: body.minY - 8, width: body.width + 16, height: top - body.minY + 9)).addClip()
        paint(wrap, nil, rgb(0.45, 0.12, 0.14), 1.4)
        NSGraphicsContext.restoreGraphicsState()
        let edge = NSBezierPath(); edge.move(to: NSPoint(x: body.minX - 1, y: top + 1)); edge.line(to: NSPoint(x: body.maxX + 1, y: top + 1))
        edge.lineWidth = 1.2; rgb(0.55, 0.40, 0.30).setStroke(); edge.stroke()
        let fx = faceX(body)
        paw(NSPoint(x: fx - 8, y: top), 4)
        paw(NSPoint(x: fx + 8, y: top), 4)
    }

    // MARK: Soda and nachos

    /// A big soda with a straw to the mouth (bubbles going up on a sip), and a tray of cheesy nachos.
    func drawSoda(_ body: NSRect) {
        let floor = groundY(body)
        // Nachos on the floor, on the far side.
        let tray = NSPoint(x: body.midX - facing * 13, y: floor + 3)
        for (dx, h, a) in [(CGFloat(-6), CGFloat(5), CGFloat(-0.4)), (0, 6, 0.2), (6, 5, 0.5), (-2.5, 7, -0.1)] {
            local(NSPoint(x: tray.x + dx, y: tray.y + h), angle: a) {
                let chip = NSBezierPath(); chip.move(to: NSPoint(x: -3.5, y: -3)); chip.line(to: NSPoint(x: 3.5, y: -3)); chip.line(to: NSPoint(x: 0, y: 4)); chip.close()
                paint(chip, rgb(1, 0.80, 0.30), rgb(0.78, 0.50, 0.12), 0.9)
            }
        }
        for (dx, dy) in [(CGFloat(-3), CGFloat(9)), (2, 10), (5, 7.5)] { paint(circle(NSPoint(x: tray.x + dx, y: tray.y + dy), 1.8), rgb(1, 0.85, 0.15)) }
        paint(NSBezierPath(ovalIn: NSRect(x: tray.x - 12, y: tray.y - 3, width: 24, height: 7)), rgb(0.93, 0.93, 0.96), ink, 1.2)

        // The soda, held on the near side, straw up to the mouth.
        // Held up beside the face, so the straw is a short hop to the mouth.
        let mouth = mouthPoint(body)
        let cup = NSPoint(x: mouth.x + facing * 15, y: max(mouth.y - 14, groundY(body) + 10))
        let lidY = cup.y + 9
        let straw = NSBezierPath(); straw.move(to: NSPoint(x: cup.x, y: lidY)); straw.line(to: NSPoint(x: cup.x, y: lidY + 4))
        straw.line(to: NSPoint(x: mouth.x + facing * 4, y: mouth.y))
        straw.lineWidth = 3.6; straw.lineCapStyle = .round; straw.lineJoinStyle = .round; ink.setStroke(); straw.stroke()
        straw.lineWidth = 2; rgb(0.95, 0.30, 0.35).setStroke(); straw.stroke()
        if let s = moment(every: 6, lasting: 1.6, offset: 1) {
            for i in 0..<3 {
                let f = min(1, max(0, s * 1.4 - CGFloat(i) * 0.15))
                let p = f < 0.5 ? NSPoint(x: cup.x, y: lidY + f * 8) : NSPoint(x: cup.x + (mouth.x + facing * 4 - cup.x) * (f - 0.5) * 2, y: lidY + 4 + (mouth.y - lidY - 4) * (f - 0.5) * 2)
                paint(circle(p, 0.8), rgb(0.45, 0.25, 0.15, f < 1 ? 1 : 0))
            }
        }
        let body2 = NSBezierPath()
        body2.move(to: NSPoint(x: cup.x - 6.5, y: cup.y + 8)); body2.line(to: NSPoint(x: cup.x + 6.5, y: cup.y + 8))
        body2.line(to: NSPoint(x: cup.x + 5, y: cup.y - 9)); body2.line(to: NSPoint(x: cup.x - 5, y: cup.y - 9)); body2.close()
        paint(body2, rgb(0.27, 0.52, 0.96))
        NSGraphicsContext.saveGraphicsState(); body2.addClip()
        let wave = NSBezierPath(); wave.move(to: NSPoint(x: cup.x - 8, y: cup.y - 2))
        wave.curve(to: NSPoint(x: cup.x + 8, y: cup.y), controlPoint1: NSPoint(x: cup.x - 3, y: cup.y + 3), controlPoint2: NSPoint(x: cup.x + 3, y: cup.y - 4))
        wave.lineWidth = 3; NSColor.white.withAlphaComponent(0.9).setStroke(); wave.stroke()
        NSGraphicsContext.restoreGraphicsState()
        paint(body2, nil, ink, 1.2)
        paint(roundRect(NSRect(x: cup.x - 7.5, y: cup.y + 7.5, width: 15, height: 2.8), 1.4), .white, ink, 1.1)
        paw(NSPoint(x: cup.x - facing * 5, y: cup.y - 2))
    }

    // MARK: Scary scene

    /// How startled it is right now (0…1): every few seconds something jumps out of the film.
    var scaredJump: CGFloat {
        guard act == .scary, let t = moment(every: 7, lasting: 1.4, offset: 2) else { return 0 }
        return sin(t * .pi)
    }

    /// Hiding behind a cushion, eyes just over the top; when something jumps out, it pulls it up over its eyes.
    func drawCushion(_ body: NSRect) {
        let eyes = eyeLine(body)
        let peek = eyes - 6.5
        let hide = eyes + 7
        let top = peek + (hide - peek) * scaredJump
        let w = min(body.width * 0.8, 58)
        let cx = faceX(body)
        // Held up in front of the face: from the floor on a small pet, a cushion's height below the eyes on a tall one.
        let bottom = max(groundY(body) - 1, top - 34)
        let r = NSRect(x: cx - w / 2, y: bottom, width: w, height: top - bottom)
        // Tassels on the top corners, then the cushion, softly puffed.
        for side in [CGFloat(-1), 1] {
            paint(circle(NSPoint(x: cx + side * (w / 2 - 1), y: top - 1), 2.2), rgb(1, 0.82, 0.3), ink, 0.9)
        }
        let cushion = roundRect(r, 9)
        paint(cushion, rgb(0.58, 0.44, 0.88), ink, 1.4)
        NSGraphicsContext.saveGraphicsState(); cushion.addClip()
        paint(NSBezierPath(ovalIn: r.insetBy(dx: w * 0.18, dy: r.height * 0.18)), rgb(0.70, 0.58, 0.95, 0.7))
        NSGraphicsContext.restoreGraphicsState()
        let stitch = roundRect(r.insetBy(dx: 3.5, dy: 3.5), 6.5)
        stitch.setLineDash([2, 2], count: 2, phase: 0); stitch.lineWidth = 0.8; rgb(0.40, 0.28, 0.65).setStroke(); stitch.stroke()
        paint(circle(NSPoint(x: r.midX, y: r.midY), 1.6), rgb(0.40, 0.28, 0.65))
        // Gripping the top edge.
        paw(NSPoint(x: cx - w / 2 + 9, y: top - 1), 4.2)
        paw(NSPoint(x: cx + w / 2 - 9, y: top - 1), 4.2)
        if scaredJump > 0.3 {
            label("!", at: NSPoint(x: cx + facing * (w / 2 + 4), y: top + 8), size: 12, color: rgb(1, 0.4, 0.35, scaredJump), weight: .black)
        }
    }

    // MARK: Tearjerker

    /// A tissue box on the floor; now and then a paw brings a tissue up to dab its eyes.
    func drawTissues(_ body: NSRect) {
        let floor = groundY(body)
        let box = NSPoint(x: body.midX + facing * (body.width / 2 - 8), y: floor)
        local(box, scale: 1.3) {
            let b = roundRect(NSRect(x: -10.5, y: 0, width: 21, height: 11), 1.8)
            paint(b, rgb(0.62, 0.80, 0.98), ink, 1.2)
            for (fx, fy) in [(CGFloat(-6), CGFloat(3.5)), (0, 6.5), (6, 3)] { paint(circle(NSPoint(x: fx, y: fy), 1.6), rgb(1, 1, 1, 0.75)) }
            paint(NSBezierPath(ovalIn: NSRect(x: -5, y: 9.2, width: 10, height: 2.6)), rgb(0.3, 0.38, 0.5))
            let tissue = NSBezierPath()
            tissue.move(to: NSPoint(x: -3.5, y: 10.5))
            tissue.curve(to: NSPoint(x: 1, y: 19), controlPoint1: NSPoint(x: -5, y: 15), controlPoint2: NSPoint(x: -2, y: 17))
            tissue.curve(to: NSPoint(x: 4, y: 10.5), controlPoint1: NSPoint(x: 4, y: 17), controlPoint2: NSPoint(x: 5.5, y: 14))
            tissue.close()
            paint(tissue, .white, rgb(0.6, 0.65, 0.75), 0.9)
        }
        // The dab: up to the eye with a tissue, a little wipe, back down.
        let rest = NSPoint(x: box.x - facing * 8, y: floor + 19)
        var p = rest
        var dabbing = false
        if let t = moment(every: 6, lasting: 2, offset: 3) {
            let eye = NSPoint(x: faceX(body) + facing * 9, y: eyeLine(body) - 3)
            let f = t < 0.3 ? t / 0.3 : (t > 0.75 ? (1 - t) / 0.25 : 1)
            p = NSPoint(x: rest.x + (eye.x - rest.x) * f, y: rest.y + (eye.y - rest.y) * f + (f == 1 ? sin(time * 18) * 1.2 : 0))
            dabbing = true
        }
        if dabbing {
            paint(NSBezierPath(ovalIn: NSRect(x: p.x - 4, y: p.y - 1, width: 8, height: 7)), .white, rgb(0.6, 0.65, 0.75), 0.9)
        }
        paw(p)
    }

    /// Wet eyes and tears rolling down.
    func drawTears(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        for dx in [CGFloat(-1), 1] {
            let ex = fx + dx * spread
            let lid = NSBezierPath()
            lid.appendArc(withCenter: NSPoint(x: ex, y: eyeY + 1), radius: 5.5, startAngle: 215, endAngle: 325)
            lid.lineWidth = 1.4; lid.lineCapStyle = .round; rgb(0.45, 0.70, 1, 0.8).setStroke(); lid.stroke()
            let t = fmod(time * 0.6 + (dx > 0 ? 0.5 : 0), 1)
            let d = NSPoint(x: ex + dx * 1.5, y: eyeY - 5 - t * 15)
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: d.x, y: d.y + 3.6))
            drop.curve(to: NSPoint(x: d.x, y: d.y - 2), controlPoint1: NSPoint(x: d.x + 2.6, y: d.y), controlPoint2: NSPoint(x: d.x + 2, y: d.y - 2))
            drop.curve(to: NSPoint(x: d.x, y: d.y + 3.6), controlPoint1: NSPoint(x: d.x - 2, y: d.y - 2), controlPoint2: NSPoint(x: d.x - 2.6, y: d.y))
            paint(drop, rgb(0.55, 0.80, 1, 1 - t), rgb(0.30, 0.55, 0.9, 1 - t), 0.8)
        }
    }
}
