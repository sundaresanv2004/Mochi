#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Something is playing in a private window, so the pet politely doesn't look: a spy disguise (Chrome),
/// a masquerade mask (Firefox), paws over the eyes (Safari), a sleep mask and earmuffs (Edge), or turned
/// right around (any other browser). Masks and paws go over the eyes (`drawPrivacyEyes`); hats, earmuffs and
/// whistling go with the body (`drawPrivacy`).
extension PetView {
    /// Turned around: no face at all, just the back of its head.
    var hidesFace: Bool { act == .turnAway && showsAct }

    /// Turned around, the tummy and its markings are out of sight: plain fur, shaded as usual. Drawn while
    /// the body is the clip.
    func drawBackFur(_ body: NSRect) {
        guard hidesFace else { return }
        species.fur.setFill()
        NSBezierPath(rect: body.insetBy(dx: -8, dy: -8)).fill()
        drawShading(body)
    }

    // MARK: Over the eyes

    /// Draws whatever covers the eyes for a privacy act. True when something was drawn (the pet's own
    /// eyewear then stays off).
    func drawPrivacyEyes(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) -> Bool {
        switch act {
        case .spy: drawSpyGlasses(fx: fx, spread: spread, eyeY: eyeY)
        case .masquerade: drawMasquerade(fx: fx, spread: spread, eyeY: eyeY)
        case .peekaboo: drawPawsOverEyes(fx: fx, spread: spread, eyeY: eyeY)
        case .sleepMask: drawSleepMask(fx: fx, spread: spread, eyeY: eyeY)
        default: return false
        }
        return true
    }

    /// Dark round spy glasses: nothing to see in there.
    func drawSpyGlasses(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        let frame = rgb(0.12, 0.12, 0.16)
        let bridge = NSBezierPath(); bridge.move(to: NSPoint(x: fx - spread + 7, y: eyeY + 1)); bridge.line(to: NSPoint(x: fx + spread - 7, y: eyeY + 1))
        bridge.lineWidth = 2; frame.setStroke(); bridge.stroke()
        for dx in [CGFloat(-1), 1] {
            let c = NSPoint(x: fx + dx * spread, y: eyeY)
            let lens = circle(c, 7.8)
            let g = NSGradient(starting: rgb(0.30, 0.32, 0.40), ending: rgb(0.08, 0.08, 0.12))
            g?.draw(in: lens, angle: -70)
            paint(lens, nil, frame, 1.8)
            let shine = NSBezierPath(); shine.appendArc(withCenter: c, radius: 5, startAngle: 110, endAngle: 160)
            shine.lineWidth = 1.4; shine.lineCapStyle = .round; NSColor.white.withAlphaComponent(0.55).setStroke(); shine.stroke()
        }
    }

    /// A purple masquerade mask with gold trim, eye slits dark.
    func drawMasquerade(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        let w = spread * 2 + 22
        let mask = NSBezierPath()
        mask.move(to: NSPoint(x: fx - w / 2, y: eyeY + 3))
        mask.curve(to: NSPoint(x: fx, y: eyeY + 5), controlPoint1: NSPoint(x: fx - w / 2 + 6, y: eyeY + 11), controlPoint2: NSPoint(x: fx - 6, y: eyeY + 9))
        mask.curve(to: NSPoint(x: fx + w / 2, y: eyeY + 3), controlPoint1: NSPoint(x: fx + 6, y: eyeY + 9), controlPoint2: NSPoint(x: fx + w / 2 - 6, y: eyeY + 11))
        mask.curve(to: NSPoint(x: fx, y: eyeY - 6), controlPoint1: NSPoint(x: fx + w / 2 - 3, y: eyeY - 9), controlPoint2: NSPoint(x: fx + 6, y: eyeY - 7))
        mask.curve(to: NSPoint(x: fx - w / 2, y: eyeY + 3), controlPoint1: NSPoint(x: fx - 6, y: eyeY - 7), controlPoint2: NSPoint(x: fx - w / 2 + 3, y: eyeY - 9))
        mask.close()
        paint(mask, rgb(0.52, 0.28, 0.78), rgb(0.95, 0.75, 0.25), 1.6)
        for dx in [CGFloat(-1), 1] {
            paint(NSBezierPath(ovalIn: NSRect(x: fx + dx * spread - 5, y: eyeY - 2.4, width: 10, height: 4.8)), rgb(0.12, 0.06, 0.18))
        }
        // A feather on one side, swaying gently.
        local(NSPoint(x: fx + facing * (w / 2 - 2), y: eyeY + 5), angle: 0.9 + sin(time * 1.6) * 0.08) {
            let quill = NSBezierPath()
            quill.move(to: .zero)
            quill.curve(to: NSPoint(x: 15, y: 0), controlPoint1: NSPoint(x: 4, y: 5), controlPoint2: NSPoint(x: 11, y: 5))
            quill.curve(to: .zero, controlPoint1: NSPoint(x: 11, y: -4), controlPoint2: NSPoint(x: 4, y: -4))
            paint(quill, rgb(0.35, 0.80, 0.75), rgb(0.15, 0.45, 0.45), 1)
        }
    }

    /// Both paws over the eyes; every so often one slides down for a quick peek.
    func drawPawsOverEyes(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        var peek: CGFloat = 0
        if let t = moment(every: 6, lasting: 1.4, offset: 2) { peek = sin(t * .pi) }
        for dx in [CGFloat(-1), 1] {
            let drop = dx == facing ? peek * 8 : 0
            beanPaw(NSPoint(x: fx + dx * (spread + 1.5), y: eyeY + 1 - drop), tilt: dx * 0.25)
        }
    }

    /// A big paw seen from the palm side, toe beans and all, so it reads as a paw over the eye.
    func beanPaw(_ c: NSPoint, tilt: CGFloat) {
        local(c, angle: tilt * facing) {
            let fill = species.style == .tough ? species.fur.blended(withFraction: 0.12, of: .black) ?? species.fur : species.fur
            paint(NSBezierPath(ovalIn: NSRect(x: -8.5, y: -8, width: 17, height: 16)), fill, species.outline, 1.8)
            let bean = rgb(1, 0.62, 0.70)
            paint(NSBezierPath(ovalIn: NSRect(x: -4.2, y: -5.5, width: 8.4, height: 6.4)), bean)
            for (bx, by) in [(CGFloat(-5), CGFloat(2.6)), (-1.7, 4.6), (1.7, 4.6), (5, 2.6)] {
                paint(NSBezierPath(ovalIn: NSRect(x: bx - 1.6, y: by - 1.5, width: 3.2, height: 3)), bean)
            }
        }
    }

    /// A pale blue sleep mask with sleepy closed eyes stitched on.
    func drawSleepMask(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        let band = roundRect(NSRect(x: fx - spread - 11, y: eyeY - 6.5, width: spread * 2 + 22, height: 13), 6.5)
        paint(band, rgb(0.62, 0.78, 0.98), rgb(0.30, 0.42, 0.70), 1.4)
        for dx in [CGFloat(-1), 1] {
            let lid = NSBezierPath(); lid.appendArc(withCenter: NSPoint(x: fx + dx * spread, y: eyeY + 1.5), radius: 4.2, startAngle: 200, endAngle: 340)
            lid.lineWidth = 1.6; lid.lineCapStyle = .round; rgb(0.25, 0.32, 0.6).setStroke(); lid.stroke()
            for k in [CGFloat(-2.5), 0, 2.5] {
                let lash = NSBezierPath(); lash.move(to: NSPoint(x: fx + dx * spread + k, y: eyeY - 2.3)); lash.line(to: NSPoint(x: fx + dx * spread + k * 1.3, y: eyeY - 4.6))
                lash.lineWidth = 1; lash.lineCapStyle = .round; lash.stroke()
            }
        }
    }

    // MARK: With the body

    /// The rest of a privacy act: the spy's hat, the earmuffs, the turned pet whistling.
    func drawPrivacy(_ body: NSRect) {
        switch act {
        case .spy: drawFedora(body)
        case .sleepMask: drawEarmuffs(body)
        case .turnAway: drawWhistling(body)
        default: break
        }
    }

    /// A grey fedora with a black band, tipped forward a little.
    func drawFedora(_ body: NSRect) {
        let top = species == .ghost ? body.maxY - 3 : body.maxY - 5
        let w = min(body.width * 0.78, 60)
        local(NSPoint(x: body.midX + facing * 2, y: top), angle: -0.08) {
            let crown = NSBezierPath()
            crown.move(to: NSPoint(x: -w * 0.3, y: 2))
            crown.curve(to: NSPoint(x: w * 0.3, y: 2), controlPoint1: NSPoint(x: -w * 0.34, y: 19), controlPoint2: NSPoint(x: w * 0.34, y: 19))
            crown.close()
            paint(crown, rgb(0.36, 0.37, 0.42), ink, 1.4)
            // The pinch in the top.
            let dent = NSBezierPath(); dent.move(to: NSPoint(x: -w * 0.12, y: 14)); dent.curve(to: NSPoint(x: w * 0.12, y: 14), controlPoint1: NSPoint(x: -4, y: 10.5), controlPoint2: NSPoint(x: 4, y: 10.5))
            dent.lineWidth = 1.1; rgb(0.22, 0.22, 0.27).setStroke(); dent.stroke()
            paint(NSBezierPath(rect: NSRect(x: -w * 0.31, y: 2, width: w * 0.62, height: 4)), rgb(0.12, 0.12, 0.15))
            paint(NSBezierPath(ovalIn: NSRect(x: -w / 2, y: -2.5, width: w, height: 7)), rgb(0.36, 0.37, 0.42), ink, 1.4)
        }
    }

    /// Fluffy pink earmuffs on a band over the head: hearing nothing either.
    func drawEarmuffs(_ body: NSRect) {
        let isGhost = species == .ghost
        let a = body.width / 2 + 2
        let b = (isGhost ? body.width / 2 : body.height * 0.58) + 2
        let c = NSPoint(x: body.midX, y: isGhost ? body.maxY - body.width / 2 : body.minY + body.height * 0.42)
        let band = NSBezierPath()
        var deg: CGFloat = 20
        while deg <= 160 { let r = deg * .pi / 180; let p = NSPoint(x: c.x + a * cos(r), y: c.y + b * sin(r)); if deg == 20 { band.move(to: p) } else { band.line(to: p) }; deg += 6 }
        band.lineWidth = 3.4; band.lineCapStyle = .round; rgb(0.85, 0.40, 0.60).setStroke(); band.stroke()
        for deg in [CGFloat(14), 166] {
            let r = deg * .pi / 180
            let p = NSPoint(x: c.x + a * cos(r), y: c.y + b * sin(r))
            // A fluffy edge: a ring of little puffs around the muff.
            for k in 0..<10 {
                let ang = CGFloat(k) * .pi / 5
                paint(circle(NSPoint(x: p.x + cos(ang) * 6.4, y: p.y + sin(ang) * 6.4), 2.6), rgb(1, 0.80, 0.88))
            }
            paint(circle(p, 6.6), rgb(1, 0.66, 0.80), rgb(0.80, 0.35, 0.55), 1.2)
            paint(circle(NSPoint(x: p.x - 1.6, y: p.y + 1.8), 1.6), NSColor.white.withAlphaComponent(0.7))
        }
    }

    /// Turned around with its back to you, whistling to itself.
    func drawWhistling(_ body: NSRect) {
        // A little tuft at the back of the head, so it reads as turned around rather than faceless.
        let tuft = NSPoint(x: body.midX, y: body.maxY - 5)
        species.outline.withAlphaComponent(0.45).setStroke()
        for dx in [CGFloat(-4), 0, 4] {
            let swirl = NSBezierPath(); swirl.move(to: NSPoint(x: tuft.x + dx, y: tuft.y))
            swirl.curve(to: NSPoint(x: tuft.x + dx * 1.7, y: tuft.y - 10), controlPoint1: NSPoint(x: tuft.x + dx + 3, y: tuft.y - 3), controlPoint2: NSPoint(x: tuft.x + dx * 1.7 - 3, y: tuft.y - 7))
            swirl.lineWidth = 1.6; swirl.lineCapStyle = .round; swirl.stroke()
        }
        guard let t = moment(every: 2.2, lasting: 2.2) else { return }
        let note = ["♪", "♫", "~"][Int(time / 2.2) % 3]
        label(note, at: NSPoint(x: body.midX + facing * (body.width / 2 + t * 6), y: body.maxY - 10 + t * 15), size: 11,
              color: rgb(0.45, 0.55, 0.85, fade(t)), weight: .bold)
    }
}
