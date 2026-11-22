#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Music: DJ, air guitar, karaoke, glow-stick rave, bongos. All of them move to the song's tempo
/// (`beatPhase`, `beatPulse`), on top of the vibe the body already does.
extension PetView {
    // MARK: DJ

    /// A turntable deck on the floor: one paw scratches the record, the other rides the mixer.
    func drawDJ(_ body: NSRect) {
        let floor = groundY(body)
        local(NSPoint(x: body.midX, y: floor), scale: 1.2) {
            let deck = roundRect(NSRect(x: -25, y: 0, width: 50, height: 11), 3.5)
            paint(deck, rgb(0.18, 0.18, 0.23), ink, 1.4)
            paint(roundRect(NSRect(x: -23, y: 1.5, width: 46, height: 2), 1), rgb(0.30, 0.30, 0.36))

            // The record, seen from a little above, spinning.
            let platter = NSBezierPath(ovalIn: NSRect(x: -3, y: 6.5, width: 25, height: 8))
            paint(platter, rgb(0.05, 0.05, 0.07), rgb(0.38, 0.38, 0.44), 1)
            rgb(0.25, 0.25, 0.30).setStroke()
            let groove = NSBezierPath(ovalIn: NSRect(x: 1, y: 7.9, width: 17, height: 5.2)); groove.lineWidth = 0.6; groove.stroke()
            paint(NSBezierPath(ovalIn: NSRect(x: 6.3, y: 9.6, width: 6.4, height: 2.2)), rgb(0.97, 0.32, 0.45))
            let spin = time * 9
            paint(circle(NSPoint(x: 9.5 + cos(spin) * 9, y: 10.5 + sin(spin) * 2.8), 0.9), NSColor.white.withAlphaComponent(0.8))

            // Mixer: a fader sliding about and two lights blinking on the beat.
            rgb(0.08, 0.08, 0.1).setStroke()
            let slot = NSBezierPath(); slot.move(to: NSPoint(x: -21, y: 5)); slot.line(to: NSPoint(x: -9, y: 5)); slot.lineWidth = 1.4; slot.stroke()
            paint(roundRect(NSRect(x: -16 + sin(time * 1.3) * 4.5, y: 3.2, width: 3, height: 3.6), 0.8), rgb(0.85, 0.85, 0.9))
            let on = beatPulse > 0.5
            paint(circle(NSPoint(x: -19, y: 8.6), 1.4), on ? rgb(0.3, 1, 0.5) : rgb(0.15, 0.35, 0.2))
            paint(circle(NSPoint(x: -14, y: 8.6), 1.4), on ? rgb(0.3, 0.2, 0.25) : rgb(1, 0.35, 0.45))
        }
        // Scratching back and forth on the record; the other paw on the mixer, bobbing to the beat.
        paw(NSPoint(x: body.midX + facing * (11.5 + sin(time * 7) * 5.5), y: floor + 15.5))
        paw(NSPoint(x: body.midX - facing * 18, y: floor + 13.5 + beatPulse * 1.5))
    }

    // MARK: Air guitar

    /// A little red electric guitar across the tummy, neck up and forward, strummed on the beat.
    func drawAirGuitar(_ body: NSRect) {
        let centre = NSPoint(x: body.midX - facing * 8, y: body.minY + body.height * 0.2)
        local(centre, angle: 0.5, scale: 1.4) {
            // Neck and headstock.
            paint(roundRect(NSRect(x: 8, y: -1.7, width: 27, height: 3.4), 1), rgb(0.60, 0.40, 0.22), ink, 1)
            rgb(0.85, 0.78, 0.6).setStroke()
            for fx in stride(from: CGFloat(13), to: 34, by: 5) {
                let fret = NSBezierPath(); fret.move(to: NSPoint(x: fx, y: -1.6)); fret.line(to: NSPoint(x: fx, y: 1.6)); fret.lineWidth = 0.5; fret.stroke()
            }
            paint(roundRect(NSRect(x: 34, y: -2.8, width: 7, height: 5.6), 1.5), rgb(0.22, 0.2, 0.24), ink, 1)
            for px in [CGFloat(36), 39] { paint(circle(NSPoint(x: px, y: 3.4), 0.9), rgb(0.85, 0.85, 0.9)) }

            // The body: two rounded bouts, a pickguard and two pickups.
            let shape = circle(NSPoint(x: -3, y: 0), 8.8)
            shape.append(circle(NSPoint(x: 5, y: 0.6), 6.6))
            shape.windingRule = .nonZero
            paint(shape, rgb(0.90, 0.20, 0.25))
            NSGraphicsContext.saveGraphicsState(); shape.addClip()
            paint(circle(NSPoint(x: 0.5, y: -4.5), 5.5), rgb(0.98, 0.95, 0.92))
            NSGraphicsContext.restoreGraphicsState()
            ink.setStroke(); circle(NSPoint(x: -3, y: 0), 8.8).stroke(); circle(NSPoint(x: 5, y: 0.6), 6.6).stroke()
            paint(roundRect(NSRect(x: -5.5, y: -2.5, width: 2.2, height: 5), 0.6), rgb(0.15, 0.15, 0.18))
            paint(roundRect(NSRect(x: 0, y: -2.5, width: 2.2, height: 5), 0.6), rgb(0.15, 0.15, 0.18))
            // Strings, shimmering as they're struck.
            NSColor.white.withAlphaComponent(0.75).setStroke()
            for sy in [CGFloat(-0.8), 0.8] {
                let s = NSBezierPath(); s.move(to: NSPoint(x: -7, y: sy)); s.line(to: NSPoint(x: 35, y: sy + sin(time * 40) * 0.3 * beatPulse))
                s.lineWidth = 0.45; s.stroke()
            }
            // One paw on the frets, one strumming down on every beat.
            paw(NSPoint(x: 26, y: 2.2), 4)
            paw(NSPoint(x: -1, y: 2 + (1 - beatPulse) * 5), 4.4)
        }
    }

    // MARK: Karaoke

    /// A microphone just under the mouth, eyes closed for the big notes, words floating up.
    func drawKaraoke(_ body: NSRect) {
        let mouth = mouthPoint(body)
        let head = NSPoint(x: mouth.x + facing * 7.5, y: mouth.y - 3 + beatPulse * 1.2)
        local(head, angle: -1.15, scale: 1.2) {
            paint(roundRect(NSRect(x: 3, y: -2.2, width: 15, height: 4.4), 2), rgb(0.16, 0.16, 0.2), ink, 1)
            paint(roundRect(NSRect(x: 2.5, y: -2.8, width: 2.4, height: 5.6), 1), rgb(0.75, 0.75, 0.8))
            paint(circle(.zero, 4.8), rgb(0.72, 0.74, 0.8), ink, 1.1)
            NSGraphicsContext.saveGraphicsState(); circle(.zero, 4.8).addClip()
            rgb(0.5, 0.52, 0.58).setStroke()
            for d in stride(from: CGFloat(-6), through: 6, by: 2.2) {
                let a = NSBezierPath(); a.move(to: NSPoint(x: d - 5, y: -5)); a.line(to: NSPoint(x: d + 5, y: 5)); a.lineWidth = 0.5; a.stroke()
                let b = NSBezierPath(); b.move(to: NSPoint(x: d - 5, y: 5)); b.line(to: NSPoint(x: d + 5, y: -5)); b.lineWidth = 0.5; b.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
            paint(circle(NSPoint(x: -1.6, y: 1.6), 1.2), NSColor.white.withAlphaComponent(0.7))
            paw(NSPoint(x: 11, y: 0), 4.2)
        }
        // The song, floating up and away: a few words, then a note.
        let words = ["la la", "♪", "ooh~", "♫"]
        if let t = moment(every: 2.4, lasting: 2.4) {
            let word = words[Int(time / 2.4) % words.count]
            label(word, at: NSPoint(x: body.midX + facing * (body.width / 2 + 2 + t * 4), y: body.maxY - 8 + t * 16), size: 9,
                  color: rgb(0.95, 0.35, 0.6, fade(t)), weight: .bold)
        }
    }

    // MARK: Glow-stick rave

    /// A neon glow stick in each paw, waving on the beat, with the colours washing over the pet.
    func drawRave(_ body: NSRect) {
        for side in [CGFloat(-1), 1] {
            let hand = handPoint(body, side: side, height: 0.42)
            let wave = 0.45 + 0.4 * sin(beatPhase * 2 + (side > 0 ? 0 : .pi))
            let colour = side > 0 ? rgb(0.35, 1, 0.45) : rgb(1, 0.35, 0.88)
            local(hand, angle: .pi / 2 - side * wave) {
                for (width, c) in [(CGFloat(12), colour.withAlphaComponent(0.25)), (5.5, colour), (1.8, NSColor.white.withAlphaComponent(0.85))] {
                    let stick = NSBezierPath(); stick.move(to: NSPoint(x: 2, y: 0)); stick.line(to: NSPoint(x: 26, y: 0))
                    stick.lineWidth = width; stick.lineCapStyle = .round; c.setStroke(); stick.stroke()
                }
                paw(.zero, 4.6)
            }
        }
    }

    /// The club lights: the body takes on each glow stick's colour in turn, on the beat.
    func drawRaveLight(_ body: NSRect) {
        let colours = [rgb(1, 0.35, 0.88), rgb(0.35, 1, 0.45), rgb(0.35, 0.8, 1)]
        let bpm = musicBpm > 0 ? musicBpm : 110
        let c = colours[Int(time * bpm / 60) % colours.count]
        c.withAlphaComponent(0.10 + 0.14 * beatPulse).setFill()
        NSBezierPath(rect: body.insetBy(dx: -6, dy: -6)).fill()
    }

    // MARK: Bongos

    /// A pair of bongos on the floor, tapped with alternate paws, each tap ringing out.
    func drawBongos(_ body: NSRect) {
        let floor = groundY(body)
        let drums: [(x: CGFloat, top: CGFloat, w: CGFloat)] = [(body.midX - facing * 12, 17, 21), (body.midX + facing * 12, 15, 18)]
        let hit = sin(beatPhase * 2)
        for (i, d) in drums.enumerated() {
            let top = floor + d.top
            let shell = NSBezierPath()
            shell.move(to: NSPoint(x: d.x - d.w / 2, y: top)); shell.line(to: NSPoint(x: d.x + d.w / 2, y: top))
            shell.line(to: NSPoint(x: d.x + d.w / 2 - 2.5, y: floor)); shell.line(to: NSPoint(x: d.x - d.w / 2 + 2.5, y: floor)); shell.close()
            paint(shell, rgb(0.66, 0.38, 0.18), ink, 1.2)
            NSGraphicsContext.saveGraphicsState(); shell.addClip()
            for band in [floor + 3, top - 3] { paint(NSBezierPath(rect: NSRect(x: d.x - d.w, y: band - 1, width: d.w * 2, height: 2)), rgb(0.42, 0.22, 0.10)) }
            NSGraphicsContext.restoreGraphicsState()
            paint(NSBezierPath(ovalIn: NSRect(x: d.x - d.w / 2, y: top - 2.4, width: d.w, height: 4.8)), rgb(0.97, 0.88, 0.70), ink, 1.1)

            // Alternate paws: down on the beat, a ring of sound when it lands.
            let strike = max(0, i == 0 ? hit : -hit)
            paw(NSPoint(x: d.x, y: top + 3 + (1 - strike) * 6))
            if strike > 0.75 {
                let grow = (strike - 0.75) * 4
                rgb(0.95, 0.6, 0.2, 1 - grow).setStroke()
                let ring = NSBezierPath(ovalIn: NSRect(x: d.x - d.w / 2 - 3 - grow * 4, y: top - 3.5 - grow, width: d.w + 6 + grow * 8, height: 7 + grow * 2))
                ring.lineWidth = 1; ring.stroke()
            }
        }
    }
}
