#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// The body: squash and stretch, shadow, shape and shading.
extension PetView {
    func drawPet(_ ctx: CGContext) {
        let sp = species
        let t = time
        var squash: CGFloat = 1 + 0.03 * sin(t * 2)    // breathing
        var lift: CGFloat = 0

        switch mood {
        case .walk:  let s = abs(sin(t * walkRate)); lift = s * 6 * sp.hopFactor;  squash = 1 - 0.05 * s
        case .chase: let s = abs(sin(t * 14)); lift = s * 9 * sp.hopFactor;  squash = 1 - 0.07 * s
        case .happy: lift = abs(sin(t * 9)) * 16; squash = 1.05
        case .sleep: squash = 1 + 0.06 * sin(t * 1.4)
        case .held:  squash = 1.12
        case .jump:  squash = 1.15
        case .dance: lift = abs(sin(t * 8)) * 8; squash = 1 + 0.06 * sin(t * 16)
        case .stretch: squash = 1.18 + 0.07 * sin(t * 5)
        case .dizzy: squash = 1 + 0.03 * sin(t * 3)
        case .sad:   squash = 0.94 + 0.015 * sin(t * 1.5)    // slumped
        case .power: squash = 1.08 + 0.03 * sin(t * 22)      // puffed up and trembling with effort
        case .idle:  break
        }
        // Bob to the beat while music plays.
        if musicBpm > 0, mood == .idle || mood == .walk || mood == .chase || mood == .sad {
            let beat = abs(sin(beatPhase))
            // Standing still it really feels it; on the move it's a lighter bounce on top of the steps.
            let groove: CGFloat = mood == .idle ? 5 : (mood == .sad ? 2 : 3)
            lift += beat * groove
            squash -= beat * groove * 0.01
        }
        // A quick bop for every key you press.
        if tap > 0, mood == .idle || mood == .walk || mood == .sad {
            lift += tap * 3.5
            squash -= tap * 0.045
        }
        squash -= impact * 0.16
        lift += hop
        // Whatever it's up to while something plays: nodding along, chewing, jumping at a scary bit.
        lift += actLift
        squash += actSquash
        // Ghosts float.
        let hover: CGFloat = sp == .ghost ? (mood == .sleep ? 1 : 7 + sin(t * 3) * 2.5) : 0

        let baseW: CGFloat, baseH: CGFloat
        switch sp {
        case .mochi: baseW = 80; baseH = 58
        case .cat: baseW = 76; baseH = 57
        case .bunny: baseW = 68; baseH = 58
        case .penguin: baseW = 70; baseH = 68
        case .ghost: baseW = 68; baseH = 66
        case .dino: baseW = 80; baseH = 70
        case .robot: baseW = 76; baseH = 68
        case .dragon: baseW = 72; baseH = 70
        case .wolf: baseW = 84; baseH = 68
        case .shark: baseW = 72; baseH = 72
        }
        let h = baseH * squash
        let w = baseW * (2 - squash)
        let body = NSRect(x: Self.canvas.midX - w / 2, y: 8 + lift + hover, width: w, height: h)

        // Shadow
        let ss = max(0.35, 1 - (lift + hover) / 60)
        NSColor.black.withAlphaComponent(0.16).setFill()
        NSBezierPath(ovalIn: NSRect(x: Self.canvas.midX - 31 * ss, y: 4, width: 62 * ss, height: 8)).fill()

        // Behind the body
        switch sp {
        case .mochi: drawSprout(ctx, body)
        case .cat: drawCatTail(body); drawCatEars(body)
        case .bunny: drawBunnyTail(body); drawBunnyEars(ctx, body)
        case .penguin: drawPenguinTuft(body); drawFlippers(ctx, body)
        case .ghost: drawGhostArms(ctx, body)
        case .dino, .robot, .dragon, .wolf, .shark: drawToughBehind(ctx, body)
        }

        // Body: flat colour, markings, soft shading, then the outline on top
        let path = bodyPath(body)
        sp.fur.setFill()
        path.fill()
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        if sp == .penguin { drawPenguinMarkings(body) }
        if sp == .cat {
            // pale tummy
            NSColor(calibratedRed: 1, green: 0.93, blue: 0.82, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: body.midX + facing * 2 - 15, y: body.minY - 4, width: 30, height: h * 0.36)).fill()
        }
        if sp.style == .tough { drawToughMarkings(body) }
        drawShading(body)
        drawActLight(body)
        NSGraphicsContext.restoreGraphicsState()
        sp.outline.setStroke()
        path.lineWidth = sp.style == .tough ? 3 : 2.5
        path.stroke()
        if sp.style == .tough { drawToughFront(ctx, body) }
        else if sp != .ghost { drawFeet(body) }     // little paws peeking out in front
        if sp == .penguin { drawScarf(ctx, body) }
        if sp == .bunny { drawBow(ctx, body) }

        drawFace(body)
        drawOutfit(ctx, body)
        drawAct(body)
        if mood == .power { drawPower(body) }
        if sweat, mood != .sleep { drawSweat(body) }
        // Headphones, unless the act shows off something else (a guitar, a mic, glow sticks…).
        if musicBpm > 0, act?.wearsHeadphones ?? true || !showsAct { drawHeadphones(body) }
        if mood == .sleep { drawZs(near: body) }
        if mood == .dance || (musicBpm > 0 && mood != .sleep) { drawNotes(near: body) }
    }

    /// A chubby gumdrop: full, flat-ish bottom and a slightly narrower round top.
    func gumdrop(_ b: NSRect, belly: CGFloat, top: CGFloat) -> NSBezierPath {
        let w = b.width, h = b.height
        let my = b.minY + h * belly
        let p = NSBezierPath()
        p.move(to: NSPoint(x: b.midX, y: b.minY))
        p.curve(to: NSPoint(x: b.maxX, y: my),
                controlPoint1: NSPoint(x: b.midX + w * 0.36, y: b.minY),
                controlPoint2: NSPoint(x: b.maxX, y: b.minY + h * 0.08))
        p.curve(to: NSPoint(x: b.midX, y: b.maxY),
                controlPoint1: NSPoint(x: b.maxX, y: b.minY + h * 0.74),
                controlPoint2: NSPoint(x: b.midX + w * top, y: b.maxY))
        p.curve(to: NSPoint(x: b.minX, y: my),
                controlPoint1: NSPoint(x: b.midX - w * top, y: b.maxY),
                controlPoint2: NSPoint(x: b.minX, y: b.minY + h * 0.74))
        p.curve(to: NSPoint(x: b.midX, y: b.minY),
                controlPoint1: NSPoint(x: b.minX, y: b.minY + h * 0.08),
                controlPoint2: NSPoint(x: b.midX - w * 0.36, y: b.minY))
        p.close()
        return p
    }

    /// Soft shading inside the (already clipped) body: a tinted rim along the bottom and a little gloss.
    func drawShading(_ body: NSRect) {
        let w = body.width, h = body.height
        let rim = NSBezierPath(rect: body.insetBy(dx: -4, dy: -4))
        rim.append(NSBezierPath(ovalIn: NSRect(x: body.minX - w * 0.10, y: body.minY + h * 0.13,
                                               width: w * 1.20, height: h * 1.1)))
        rim.windingRule = .evenOdd
        species.shade.setFill()
        rim.fill()

        if species == .cat || species == .penguin || species == .shark || species == .robot {
            NSColor.white.withAlphaComponent(species == .penguin ? 0.22 : 0.45).setFill()
            let g = NSBezierPath(ovalIn: NSRect(x: -6, y: -3, width: 12, height: 6))
            var t = AffineTransform(translationByX: body.minX + w * 0.25, byY: body.maxY - h * 0.2)
            t.rotate(byRadians: 0.5)
            g.transform(using: t)
            g.fill()
        }
    }

    func bodyPath(_ body: NSRect) -> NSBezierPath {
        switch species {
        case .mochi:
            return gumdrop(body, belly: 0.38, top: 0.30)
        case .cat, .bunny:
            return gumdrop(body, belly: 0.42, top: 0.29)
        case .penguin:
            return gumdrop(body, belly: 0.36, top: 0.26)
        case .dino, .dragon, .robot, .wolf, .shark:
            return toughBodyPath(body)
        case .ghost:
            // dome on top, wavy hem at the bottom
            let r = body.width / 2
            let hemY = body.minY + 10
            let p = NSBezierPath()
            p.move(to: NSPoint(x: body.minX, y: hemY))
            p.line(to: NSPoint(x: body.minX, y: body.maxY - r))
            p.appendArc(withCenter: NSPoint(x: body.midX, y: body.maxY - r), radius: r,
                        startAngle: 180, endAngle: 0, clockwise: true)
            p.line(to: NSPoint(x: body.maxX, y: hemY))
            let n = 3
            let sw = body.width / CGFloat(n)
            for i in 0..<n {
                let x1 = body.maxX - sw * CGFloat(i), x2 = x1 - sw
                let sag = hemY - 13 + sin(time * 6 + CGFloat(i)) * 2
                p.curve(to: NSPoint(x: x2, y: hemY),
                        controlPoint1: NSPoint(x: x1 - sw * 0.1, y: sag),
                        controlPoint2: NSPoint(x: x2 + sw * 0.1, y: sag))
            }
            p.close()
            p.lineJoinStyle = .round
            return p
        }
    }
}
