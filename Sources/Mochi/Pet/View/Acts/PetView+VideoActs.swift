#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Videos (YouTube and the like): phone binge, snack attack, smash that like, subscribe bell, comment typer.
/// The screen's glow and its reflection in the eyes (PetView+Media) go with all of them.
extension PetView {
    // MARK: Phone binge

    /// A phone held sideways in both paws, a video playing on it, its light on the pet's face.
    func drawPhone(_ body: NSRect) {
        let c = NSPoint(x: faceX(body) - facing * 1, y: body.minY + body.height * 0.27 + sin(time * 1.1) * 0.6)
        local(c, angle: -0.06) {
            let frame = roundRect(NSRect(x: -15, y: -8.5, width: 30, height: 17), 3.8)
            paint(frame, rgb(0.16, 0.17, 0.24), ink, 1.3)
            let screen = NSRect(x: -12.8, y: -6.5, width: 25.6, height: 13)
            NSGraphicsContext.saveGraphicsState()
            roundRect(screen, 1.8).addClip()
            // The video: a sky that slowly changes, hills, and something bouncing across.
            let sky = NSGradient(starting: rgb(0.45, 0.78, 1), ending: rgb(0.75, 0.6, 1).blended(withFraction: (sin(time * 0.5) + 1) / 2, of: rgb(1, 0.75, 0.55))!)
            sky?.draw(in: screen, angle: -90)
            paint(circle(NSPoint(x: -4, y: -9), 9), rgb(0.40, 0.78, 0.45))
            paint(circle(NSPoint(x: 9, y: -11), 9), rgb(0.30, 0.68, 0.38))
            let bx = -11 + fmod(time * 7, 24)
            paint(circle(NSPoint(x: bx, y: -2 + abs(sin(time * 4)) * 6), 1.9), rgb(1, 0.85, 0.3))
            // The progress bar creeping along.
            paint(NSBezierPath(rect: NSRect(x: -12.8, y: -6.5, width: 25.6, height: 1.3)), NSColor.white.withAlphaComponent(0.5))
            let done = fmod(time / 40, 1)
            paint(NSBezierPath(rect: NSRect(x: -12.8, y: -6.5, width: 25.6 * done, height: 1.3)), rgb(0.95, 0.15, 0.2))
            paint(circle(NSPoint(x: -12.8 + 25.6 * done, y: -5.85), 1.3), rgb(0.95, 0.15, 0.2))
            // Now and then the play button flashes up.
            if let p = moment(every: 11, lasting: 1.2, offset: 6) {
                paint(roundRect(NSRect(x: -5, y: -3.2, width: 10, height: 7), 2), rgb(0.95, 0.15, 0.2, fade(p)))
                let tri = NSBezierPath(); tri.move(to: NSPoint(x: -1.6, y: -1.6)); tri.line(to: NSPoint(x: -1.6, y: 2.6)); tri.line(to: NSPoint(x: 2.2, y: 0.5)); tri.close()
                paint(tri, NSColor.white.withAlphaComponent(fade(p)))
            }
            NSGraphicsContext.restoreGraphicsState()
            paint(circle(NSPoint(x: 13.6, y: 0), 0.8), rgb(0.35, 0.35, 0.45))
            paw(NSPoint(x: -15, y: -2), 4.2)
            paw(NSPoint(x: 15, y: -2), 4.2)
        }
    }

    // MARK: Snack attack

    /// A bowl of chips on the floor: a paw dives in, a chip goes to the mouth, crumbs fall.
    func drawSnacks(_ body: NSRect) {
        let floor = groundY(body)
        let bowl = NSPoint(x: body.midX + facing * 6, y: floor)
        let k: CGFloat = 1.3
        let mouth = mouthPoint(body)
        // Chips first, so the bowl's front covers their bottoms.
        let chips: [(CGFloat, CGFloat, CGFloat)] = [(-9, 9, -0.5), (-3, 11, 0.3), (3, 10, -0.2), (9, 9, 0.6), (0, 8, 0.1)]
        for (dx, h, tilt) in chips {
            local(NSPoint(x: bowl.x + dx * k * facing, y: bowl.y + (h - 2) * k), angle: tilt, scale: k) {
                let chip = NSBezierPath(); chip.move(to: NSPoint(x: -3.6, y: -2.5)); chip.line(to: NSPoint(x: 3.6, y: -2.5)); chip.line(to: NSPoint(x: 0.4, y: 4)); chip.close()
                paint(chip, rgb(1, 0.78, 0.25), rgb(0.75, 0.45, 0.1), 0.9)
                paint(circle(NSPoint(x: -0.6, y: -0.4), 0.5), rgb(0.85, 0.35, 0.15))
            }
        }
        let rim = NSRect(x: bowl.x - 19.5, y: bowl.y + 6, width: 39, height: 6)
        let shell = NSBezierPath()
        shell.move(to: NSPoint(x: rim.minX, y: rim.midY))
        shell.curve(to: NSPoint(x: rim.maxX, y: rim.midY), controlPoint1: NSPoint(x: rim.minX + 2, y: bowl.y - 4), controlPoint2: NSPoint(x: rim.maxX - 2, y: bowl.y - 4))
        shell.close()
        paint(shell, rgb(0.36, 0.56, 0.96), ink, 1.3)
        paint(NSBezierPath(rect: NSRect(x: rim.minX + 4, y: bowl.y + 4.4, width: 31, height: 1.6)), NSColor.white.withAlphaComponent(0.6))

        // The grab: down into the bowl, up to the mouth with a chip, back again.
        let rest = handPoint(body, side: 1, height: 0.24)
        var p = rest
        var holding = false
        if let t = moment(every: 5, lasting: 2.2) {
            let dip = NSPoint(x: bowl.x + facing * 5, y: bowl.y + 12)
            let eat = NSPoint(x: mouth.x + facing * 5, y: mouth.y - 3)
            func lerp(_ a: NSPoint, _ b: NSPoint, _ f: CGFloat) -> NSPoint { NSPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f) }
            if t < 0.3 { p = lerp(rest, dip, t / 0.3) }
            else if t < 0.65 { p = lerp(dip, eat, (t - 0.3) / 0.35); holding = true }
            else { p = lerp(eat, rest, (t - 0.65) / 0.35) }
            if t > 0.65 {
                for i in 0..<3 {
                    let f = (t - 0.65) / 0.35
                    paint(circle(NSPoint(x: mouth.x + facing * (3 + CGFloat(i) * 2), y: mouth.y - 6 - f * (8 + CGFloat(i) * 3)), 0.8),
                          rgb(1, 0.78, 0.25, 1 - f))
                }
            }
        }
        if holding {
            local(NSPoint(x: p.x + facing * 2, y: p.y + 4), angle: 0.4) {
                let chip = NSBezierPath(); chip.move(to: NSPoint(x: -3, y: -2)); chip.line(to: NSPoint(x: 3, y: -2)); chip.line(to: NSPoint(x: 0, y: 3.5)); chip.close()
                paint(chip, rgb(1, 0.78, 0.25), rgb(0.75, 0.45, 0.1), 0.9)
            }
        }
        paw(p)
    }

    // MARK: Smash that like

    /// A red thumbs-up sign on a stick; every so often it's thrust up high with a sparkle.
    func drawLikeSign(_ body: NSRect) {
        let hand = handPoint(body, side: 1, height: 0.30)
        var up: CGFloat = 0
        if let t = moment(every: 6, lasting: 2.6, offset: 1) {
            up = t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1)
            up *= 1 + 0.12 * sin(t * 30) * (t < 0.3 ? 1 : 0)       // a little bounce as it goes up
        }
        let length = 11 + 9 * up
        local(hand, angle: 0.18 - 0.12 * up, scale: 1.35) {
            paint(roundRect(NSRect(x: -1, y: 0, width: 2.2, height: length), 1), rgb(0.70, 0.50, 0.30), ink, 0.9)
            let r = 6.5 + 2 * up
            let centre = NSPoint(x: 0, y: length + r - 1)
            paint(circle(centre, r), rgb(0.93, 0.20, 0.24), ink, 1.3)
            // The thumb: a fist with the thumb pointing up.
            let s = r / 8
            let fist = roundRect(NSRect(x: centre.x - 3.2 * s, y: centre.y - 4 * s, width: 6.4 * s, height: 5.4 * s), 1.6 * s)
            let thumb = roundRect(NSRect(x: centre.x - 2.6 * s, y: centre.y, width: 2.8 * s, height: 5 * s), 1.4 * s)
            paint(thumb, .white); paint(fist, .white)
            rgb(0.93, 0.20, 0.24).setStroke()
            for k in 0..<3 {
                let line = NSBezierPath(); line.move(to: NSPoint(x: centre.x + 0.2 * s, y: centre.y - 2.6 * s + CGFloat(k) * 1.4 * s))
                line.line(to: NSPoint(x: centre.x + 3.2 * s, y: centre.y - 2.6 * s + CGFloat(k) * 1.4 * s)); line.lineWidth = 0.5; line.stroke()
            }
            paw(NSPoint(x: 0, y: 2), 4.2)
        }
        guard up > 0.6 else { return }
        for i in 0..<3 {
            let a = time * 3 + CGFloat(i) * 2.1
            let sp = NSPoint(x: hand.x + facing * 3 + cos(a) * 15, y: hand.y + 38 + sin(a) * 10)
            label("✦", at: sp, size: 6, color: rgb(1, 0.8, 0.25, up), weight: .bold)
        }
    }

    // MARK: Subscribe bell

    /// A red SUBSCRIBE button on the floor; now and then a paw presses it, it turns grey and the bell rings.
    func drawSubscribe(_ body: NSRect) {
        let floor = groundY(body)
        let button = NSPoint(x: body.midX + facing * 2, y: floor + 6.5)
        var press: CGFloat = 0
        var subscribed = false
        if let t = moment(every: 9, lasting: 4.5, offset: 2) {
            press = t < 0.12 ? sin(t / 0.12 * .pi) : 0
            subscribed = t > 0.08
        }
        let pill = roundRect(NSRect(x: button.x - 21, y: button.y - 6.5 - press, width: 42, height: 13), 6.5)
        paint(pill, subscribed ? rgb(0.62, 0.62, 0.66) : rgb(0.93, 0.14, 0.18), ink, 1.3)
        label(subscribed ? "SUBSCRIBED" : "SUBSCRIBE", at: NSPoint(x: button.x, y: button.y - press), size: 6.2,
              color: .white, weight: .black)

        // The bell, forward of the button; it swings and rings once subscribed.
        let bell = NSPoint(x: min(max(button.x + facing * 28, 9), Self.side - 9), y: floor + 11)
        let swing = subscribed ? sin(time * 22) * 0.35 * max(0, 1 - (moment(every: 9, lasting: 4.5, offset: 2) ?? 1)) : 0
        local(bell, angle: swing, scale: 1.3) {
            let shape = NSBezierPath()
            shape.move(to: NSPoint(x: -5.5, y: -3))
            shape.curve(to: NSPoint(x: 0, y: 6), controlPoint1: NSPoint(x: -5, y: 2), controlPoint2: NSPoint(x: -4, y: 6))
            shape.curve(to: NSPoint(x: 5.5, y: -3), controlPoint1: NSPoint(x: 4, y: 6), controlPoint2: NSPoint(x: 5, y: 2))
            shape.close()
            paint(shape, rgb(1, 0.80, 0.25), ink, 1.1)
            paint(circle(NSPoint(x: 0, y: -4), 1.5), rgb(1, 0.80, 0.25), ink, 0.9)
            paint(circle(NSPoint(x: 0, y: 7), 1.1), rgb(1, 0.80, 0.25), ink, 0.9)
        }
        if subscribed, swing != 0 {
            for side in [CGFloat(-1), 1] {
                let ring = NSBezierPath()
                ring.appendArc(withCenter: bell, radius: 9, startAngle: side > 0 ? -30 : 150, endAngle: side > 0 ? 30 : 210)
                ring.lineWidth = 1.2; ring.lineCapStyle = .round; rgb(1, 0.7, 0.2, 0.9).setStroke(); ring.stroke()
            }
        }
        paw(NSPoint(x: button.x - facing * 8, y: button.y + 8 - press * 3))
    }

    // MARK: Comment typer

    /// A little laptop on the floor, paws typing away, comments popping up and floating off.
    func drawComments(_ body: NSRect) {
        let floor = groundY(body)
        let base = NSPoint(x: body.midX + facing * 3, y: floor)
        local(base, scale: 1.25) {
            // The lid, seen from behind (the screen faces the pet), and the keyboard deck in front.
            let lid = roundRect(NSRect(x: -14, y: 4, width: 28, height: 17), 2.2)
            paint(lid, rgb(0.80, 0.82, 0.88), ink, 1.3)
            let heart = NSBezierPath()
            heart.move(to: NSPoint(x: 0, y: 10))
            heart.curve(to: NSPoint(x: 0, y: 15.5), controlPoint1: NSPoint(x: -4.5, y: 13), controlPoint2: NSPoint(x: -2.5, y: 17))
            heart.curve(to: NSPoint(x: 0, y: 10), controlPoint1: NSPoint(x: 2.5, y: 17), controlPoint2: NSPoint(x: 4.5, y: 13))
            paint(heart, rgb(1, 0.55, 0.7))
            let deck = NSBezierPath()
            deck.move(to: NSPoint(x: -17, y: 0)); deck.line(to: NSPoint(x: 17, y: 0)); deck.line(to: NSPoint(x: 14.5, y: 4.5)); deck.line(to: NSPoint(x: -14.5, y: 4.5)); deck.close()
            paint(deck, rgb(0.72, 0.74, 0.80), ink, 1.2)
            // The screen's light spilling over the top edge.
            paint(NSBezierPath(ovalIn: NSRect(x: -12, y: 19.5, width: 24, height: 4)), rgb(0.6, 0.85, 1, 0.35 + 0.15 * sin(time * 3)))
        }
        // Typing: paws bouncing in turn.
        let tap = sin(time * 16)
        paw(NSPoint(x: base.x - 9, y: floor + 7.5 + max(0, tap) * 2.5), 4.4)
        paw(NSPoint(x: base.x + 9, y: floor + 7.5 + max(0, -tap) * 2.5), 4.4)

        // Comments, posted one after another.
        let posts = ["lol", "first!", "😂", "W", "+1", "so true", "🔥"]
        guard let t = moment(every: 2.8, lasting: 2.8) else { return }
        let text = posts[Int(time / 2.8) % posts.count]
        let p = NSPoint(x: min(max(body.midX + facing * (body.width / 2 + t * 4), 16), Self.side - 16), y: min(body.maxY - 6 + t * 16, Self.side - 8))
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 6.5, weight: .bold)]
        let w = (text as NSString).size(withAttributes: attrs).width
        let bubble = roundRect(NSRect(x: p.x - w / 2 - 3.5, y: p.y - 5, width: w + 7, height: 10), 4)
        let tail = NSBezierPath(); tail.move(to: NSPoint(x: p.x - facing * 2, y: p.y - 5)); tail.line(to: NSPoint(x: p.x - facing * 5, y: p.y - 8.5)); tail.line(to: NSPoint(x: p.x - facing * 5.5, y: p.y - 5)); tail.close()
        let a = fade(t)
        paint(tail, NSColor.white.withAlphaComponent(a), ink.withAlphaComponent(a), 0.9)
        paint(bubble, NSColor.white.withAlphaComponent(a), ink.withAlphaComponent(a), 0.9)
        label(text, at: p, size: 6.5, color: rgb(0.2, 0.2, 0.3, a), weight: .bold)
    }
}
