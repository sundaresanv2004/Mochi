#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// The tough pets: Rex the dino, Bolt the mech, Ember the dragon, Fang the wolf and Chomp the shark.
/// They are built from angular, rounded-corner polygons laid out inside the body box, so squash and
/// stretch still work, and they share one scowling face instead of the round sparkly one.
extension PetView {
    // MARK: Geometry helpers

    /// A point inside the body box: `u` runs -1…1 across, `v` runs 0…1 from the ground up.
    func bp(_ b: NSRect, _ u: CGFloat, _ v: CGFloat) -> NSPoint {
        NSPoint(x: b.midX + u * b.width / 2, y: b.minY + v * b.height)
    }

    /// A polygon with softened corners.
    func roundedPoly(_ pts: [NSPoint], radius: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        let n = pts.count
        guard n > 2 else { return p }
        p.move(to: NSPoint(x: (pts[n - 1].x + pts[0].x) / 2, y: (pts[n - 1].y + pts[0].y) / 2))
        for i in 0..<n { p.appendArc(from: pts[i], to: pts[(i + 1) % n], radius: radius) }
        p.close()
        p.lineJoinStyle = .round
        return p
    }

    /// Mirrors the right half of a silhouette (listed top to bottom) into a full outline.
    func symmetric(_ b: NSRect, _ half: [(CGFloat, CGFloat)]) -> [NSPoint] {
        let right = half.map { bp(b, $0.0, $0.1) }
        let left = half.reversed().filter { $0.0 != 0 }.map { bp(b, -$0.0, $0.1) }
        return right + left
    }

    func paint(_ p: NSBezierPath, fill: NSColor?, stroke: NSColor? = nil, width: CGFloat = 2.5) {
        if let fill { fill.setFill(); p.fill() }
        if let stroke { stroke.setStroke(); p.lineWidth = width; p.stroke() }
    }

    /// How far the face slides towards where the pet is looking.
    var faceShift: CGFloat { facing * 4 }

    func toughBodyPath(_ b: NSRect) -> NSBezierPath {
        switch species {
        case .wolf:
            // a head with shaggy cheek tufts
            return roundedPoly(symmetric(b, [(0, 1), (0.61, 0.90), (0.96, 0.63), (0.78, 0.51), (1.0, 0.37), (0.70, 0.24), (0.61, 0)]), radius: 5)
        case .dino:
            // a big boxy head and jaw on a narrower body
            return roundedPoly(symmetric(b, [(0.80, 1.0), (1.0, 0.84), (1.0, 0.52), (0.85, 0.40), (0.62, 0.36), (0.72, 0)]), radius: 6)
        case .dragon:
            return roundedPoly(symmetric(b, [(0, 1), (0.70, 0.90), (1.0, 0.64), (0.76, 0.40), (0.88, 0)]), radius: 5)
        case .robot:
            // helmet on armoured shoulders
            return roundedPoly(symmetric(b, [(0.62, 1.0), (0.78, 0.86), (0.78, 0.56), (1.0, 0.50), (1.0, 0.14), (0.70, 0)]), radius: 3.5)
        default:
            // shark: a torpedo standing on its tail
            let p = NSBezierPath()
            p.move(to: bp(b, 0, 1))
            p.curve(to: bp(b, 1.0, 0.27), controlPoint1: bp(b, 0.86, 0.97), controlPoint2: bp(b, 1.10, 0.58))
            p.curve(to: bp(b, 0, 0), controlPoint1: bp(b, 0.94, 0.07), controlPoint2: bp(b, 0.60, 0))
            p.curve(to: bp(b, -1.0, 0.27), controlPoint1: bp(b, -0.60, 0), controlPoint2: bp(b, -0.94, 0.07))
            p.curve(to: bp(b, 0, 1), controlPoint1: bp(b, -1.10, 0.58), controlPoint2: bp(b, -0.86, 0.97))
            p.close()
            return p
        }
    }

    // MARK: Behind the body

    func drawToughBehind(_ ctx: CGContext, _ b: NSRect) {
        let sp = species
        let d = -facing                       // the side the pet's back is on
        let moving = mood == .walk || mood == .chase
        switch sp {
        case .wolf:
            // bushy tail with a pale tip
            let wag = sin(time * (moving ? 9 : 2.5)) * (mood == .sad ? 1 : 3)
            let droop: CGFloat = mood == .sad || mood == .sleep ? 20 : 0
            let base = bp(b, d * 0.55, 0.14)
            let t1 = NSPoint(x: base.x + d * 24 + wag, y: base.y + 30 - droop)
            let t2 = NSPoint(x: base.x + d * 34 + wag, y: base.y + 16 - droop * 0.8)
            let tail = roundedPoly([bp(b, d * 0.5, 0.28), t1, t2, NSPoint(x: base.x + d * 22, y: base.y - 5), bp(b, d * 0.5, 0.02)], radius: 4)
            paint(tail, fill: sp.fur)
            NSGraphicsContext.saveGraphicsState()
            tail.addClip()
            sp.accent.setFill()
            NSBezierPath(ovalIn: NSRect(x: (t1.x + t2.x) / 2 - 9, y: (t1.y + t2.y) / 2 - 7, width: 18, height: 18)).fill()
            NSGraphicsContext.restoreGraphicsState()
            paint(tail, fill: nil, stroke: sp.outline, width: 2.8)
            // tall pointed ears that flatten when it is sad
            let flat: CGFloat = mood == .sad ? 1 : 0
            for s in [CGFloat(-1), 1] {
                let tip = bp(b, s * (0.66 + flat * 0.30), 1.22 - flat * 0.16)
                let pts = [bp(b, s * 0.80, 0.72), tip, bp(b, s * 0.12, 0.93)]
                paint(roundedPoly(pts, radius: 2.5), fill: sp.fur, stroke: sp.outline, width: 2.8)
                let cx = (pts[0].x + pts[1].x + pts[2].x) / 3, cy = (pts[0].y + pts[1].y + pts[2].y) / 3
                let inner = pts.map { NSPoint(x: cx + ($0.x - cx) * 0.48, y: cy + ($0.y - cy) * 0.48) }
                paint(roundedPoly(inner, radius: 1.5), fill: NSColor(calibratedRed: 0.24, green: 0.27, blue: 0.33, alpha: 1))
            }

        case .shark:
            let dark = NSColor(calibratedRed: 0.19, green: 0.35, blue: 0.48, alpha: 1)
            // tail fin
            let wag = sin(time * (moving ? 10 : 3)) * 3
            let base = bp(b, d * 0.80, 0.21)
            let tail = roundedPoly([NSPoint(x: base.x, y: base.y + 7), NSPoint(x: base.x + d * 18 + wag, y: base.y + 19),
                                    NSPoint(x: base.x + d * 11, y: base.y), NSPoint(x: base.x + d * 18 + wag, y: base.y - 14),
                                    NSPoint(x: base.x, y: base.y - 7)], radius: 2)
            paint(tail, fill: dark, stroke: sp.outline, width: 2.8)
            // dorsal fin, swept back, with a notch bitten out of it
            let fin = roundedPoly([bp(b, -d * 0.34, 0.93), NSPoint(x: bp(b, d * 0.44, 1).x, y: b.maxY + 13), bp(b, d * 0.42, 0.84)], radius: 2)
            paint(fin, fill: dark, stroke: sp.outline, width: 2.8)
            // side fins
            for s in [CGFloat(-1), 1] {
                var ang: CGFloat = sin(time * 2 + s) * 0.06
                switch mood {
                case .walk, .chase: ang = sin(time * walkRate + (s < 0 ? 0 : .pi)) * 0.3
                case .idle where vibing: ang = 0.3 + abs(sin(beatPhase)) * 0.4
                case .happy, .dance, .jump, .power: ang = 1.0 + sin(time * 14) * 0.3
                case .held: ang = 0.9 + sin(time * 20) * 0.35
                case .stretch: ang = 1.2
                case .dizzy: ang = 0.5 + sin(time * 12) * 0.3
                case .sad, .sleep: ang = -0.25
                default: break
                }
                let pivot = bp(b, s * 0.90, 0.42)
                ctx.saveGState()
                ctx.translateBy(x: pivot.x, y: pivot.y)
                ctx.rotate(by: s * ang)
                let f = roundedPoly([NSPoint(x: -s * 3, y: 5), NSPoint(x: s * 18, y: -11), NSPoint(x: -s * 2, y: -9)], radius: 2)
                paint(f, fill: dark, stroke: sp.outline, width: 2.8)
                ctx.restoreGState()
            }

        case .dino:
            let wag = sin(time * (moving ? 9 : 2.5)) * 4
            let base = bp(b, d * 0.62, 0.16)
            let tail = roundedPoly([NSPoint(x: base.x, y: base.y + 10), NSPoint(x: base.x + d * 31, y: base.y - 3 + wag),
                                    NSPoint(x: base.x, y: base.y - 10)], radius: 2)
            paint(tail, fill: sp.fur, stroke: sp.outline, width: 2.8)
            // jagged orange plates on top of the head
            for k in [CGFloat(-0.5), 0, 0.5] {
                let x = b.midX + k * b.width / 2, y = b.maxY - 3
                let plate = roundedPoly([NSPoint(x: x - 6.5, y: y), NSPoint(x: x + d * 2.5, y: y + 14), NSPoint(x: x + 6.5, y: y)], radius: 1.5)
                paint(plate, fill: NSColor(calibratedRed: 0.90, green: 0.48, blue: 0.16, alpha: 1),
                      stroke: NSColor(calibratedRed: 0.46, green: 0.21, blue: 0.04, alpha: 1), width: 2.2)
            }

        case .dragon:
            drawDragonTail(b)
            // spread, ragged wings
            let active = moving || mood == .happy || mood == .jump || mood == .held || mood == .power
            let flap: CGFloat = mood == .sleep || mood == .sad ? -0.22 : sin(time * (active ? 15 : 3.5)) * (active ? 0.10 : 0.04)
            for s in [CGFloat(-1), 1] {
                let root = bp(b, s * 0.72, 0.55), tip = bp(b, s * 1.50, 0.92 + flap)
                let wing = roundedPoly([root, tip, bp(b, s * 1.34, 0.63 + flap * 0.6), bp(b, s * 1.50, 0.45 + flap * 0.5),
                                        bp(b, s * 1.16, 0.46 + flap * 0.3), bp(b, s * 1.28, 0.25), bp(b, s * 0.68, 0.30)], radius: 1.5)
                paint(wing, fill: NSColor(calibratedRed: 0.47, green: 0.11, blue: 0.13, alpha: 1), stroke: sp.outline, width: 2.6)
                let bone = NSBezierPath()
                bone.move(to: root); bone.line(to: NSPoint(x: tip.x - s * 3, y: tip.y - 3))
                bone.lineCapStyle = .round
                paint(bone, fill: nil, stroke: sp.outline.withAlphaComponent(0.7), width: 1.6)
            }
            for s in [CGFloat(-1), 1] {
                let horn = roundedPoly([bp(b, s * 0.70, 0.85), NSPoint(x: bp(b, s * 0.94, 1).x, y: b.maxY + 13), bp(b, s * 0.30, 0.96)], radius: 1.5)
                paint(horn, fill: NSColor(calibratedRed: 0.95, green: 0.89, blue: 0.78, alpha: 1), stroke: sp.outline, width: 2.4)
            }

        case .robot:
            // a comms blade with a warning light
            let foot = bp(b, d * 0.40, 0.97)
            let top = NSPoint(x: foot.x + d * 4, y: b.maxY + 11)
            let rod = NSBezierPath()
            rod.move(to: foot); rod.line(to: top)
            rod.lineCapStyle = .round
            paint(rod, fill: nil, stroke: sp.outline, width: 6)
            paint(rod, fill: nil, stroke: sp.foot, width: 2.4)
            let on = mood == .happy || mood == .dance || mood == .power || fmod(time, 1.4) < 0.7
            let bulb = NSBezierPath(ovalIn: NSRect(x: top.x - 3.5, y: top.y - 2, width: 7, height: 7))
            paint(bulb, fill: on ? NSColor(calibratedRed: 1.00, green: 0.30, blue: 0.24, alpha: 1) : NSColor(calibratedRed: 0.45, green: 0.16, blue: 0.14, alpha: 1),
                  stroke: sp.outline, width: 1.8)

        default:
            break
        }
    }

    func drawDragonTail(_ body: NSRect) {
        let dir = -facing
        let base = NSPoint(x: body.midX + dir * (body.width / 2 - 8), y: body.minY + body.height * 0.16)
        let wag = sin(time * (mood == .walk || mood == .chase ? 9 : 3)) * 5
        let end = NSPoint(x: base.x + dir * 24 + wag, y: base.y + 22)
        let p = NSBezierPath()
        p.move(to: base)
        p.curve(to: end, controlPoint1: NSPoint(x: base.x + dir * 26, y: base.y), controlPoint2: NSPoint(x: base.x + dir * 30 + wag, y: base.y + 12))
        p.lineCapStyle = .round
        p.lineWidth = 10.5; species.outline.setStroke(); p.stroke()
        p.lineWidth = 5.5; species.fur.setStroke(); p.stroke()
        // the flame at the tip
        let flick = sin(time * 12) * 1.5
        let flame = NSBezierPath()
        flame.move(to: NSPoint(x: end.x - 6, y: end.y))
        flame.curve(to: NSPoint(x: end.x + flick, y: end.y + 16), controlPoint1: NSPoint(x: end.x - 7, y: end.y + 7), controlPoint2: NSPoint(x: end.x - 2, y: end.y + 9))
        flame.curve(to: NSPoint(x: end.x + 6, y: end.y), controlPoint1: NSPoint(x: end.x + 3, y: end.y + 9), controlPoint2: NSPoint(x: end.x + 7, y: end.y + 7))
        flame.curve(to: NSPoint(x: end.x - 6, y: end.y), controlPoint1: NSPoint(x: end.x + 5, y: end.y - 6), controlPoint2: NSPoint(x: end.x - 5, y: end.y - 6))
        flame.lineJoinStyle = .round
        paint(flame, fill: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.20, alpha: 1),
              stroke: NSColor(calibratedRed: 0.76, green: 0.30, blue: 0.05, alpha: 1), width: 1.8)
    }

    // MARK: Markings (drawn clipped to the body)

    func drawToughMarkings(_ b: NSRect) {
        let sp = species
        let sx = faceShift * 0.5 / (b.width / 2)        // markings lean a little with the face
        switch sp {
        case .wolf:
            let chest = roundedPoly([bp(b, sx - 0.40, -0.08), bp(b, sx - 0.30, 0.29), bp(b, sx, 0.18), bp(b, sx + 0.30, 0.29), bp(b, sx + 0.40, -0.08)], radius: 2)
            paint(chest, fill: sp.accent)
        case .shark:
            sp.accent.setFill()
            NSBezierPath(ovalIn: NSRect(x: b.midX + faceShift * 0.5 - b.width * 0.41, y: b.minY - b.height * 0.25,
                                        width: b.width * 0.82, height: b.height * 0.71)).fill()
            // gill slits
            sp.outline.withAlphaComponent(0.8).setStroke()
            for s in [CGFloat(-1), 1] {
                for v in [CGFloat(0.60), 0.54, 0.48] {
                    let g = NSBezierPath()
                    g.move(to: bp(b, s * 0.97, v)); g.line(to: bp(b, s * 0.78, v - 0.035))
                    g.lineWidth = 1.7; g.lineCapStyle = .round; g.stroke()
                }
            }
        case .dino:
            // the lower jaw is a shade darker than the head
            NSColor(calibratedRed: 0.28, green: 0.52, blue: 0.26, alpha: 1).setFill()
            NSRect(x: b.minX - 2, y: b.minY + b.height * 0.36, width: b.width + 4, height: b.height * 0.16).fill()
            let belly = roundedPoly([bp(b, sx - 0.36, 0.33), bp(b, sx + 0.36, 0.33), bp(b, sx + 0.46, -0.08), bp(b, sx - 0.46, -0.08)], radius: 3)
            paint(belly, fill: NSColor(calibratedRed: 0.81, green: 0.88, blue: 0.62, alpha: 1))
        case .dragon:
            let belly = roundedPoly([bp(b, sx - 0.42, -0.08), bp(b, sx - 0.30, 0.35), bp(b, sx + 0.30, 0.35), bp(b, sx + 0.42, -0.08)], radius: 3)
            paint(belly, fill: NSColor(calibratedRed: 0.95, green: 0.69, blue: 0.35, alpha: 1))
            NSGraphicsContext.saveGraphicsState()
            belly.addClip()
            NSColor(calibratedRed: 0.76, green: 0.47, blue: 0.14, alpha: 1).setStroke()
            for v in [CGFloat(0.25), 0.15, 0.05] {
                let l = NSBezierPath()
                l.move(to: bp(b, -1, v)); l.line(to: bp(b, 1, v))
                l.lineWidth = 1.4; l.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
        case .robot:
            let plate = roundedPoly([bp(b, sx - 0.52, 0.45), bp(b, sx + 0.52, 0.45), bp(b, sx + 0.36, 0.05), bp(b, sx - 0.36, 0.05)], radius: 2)
            paint(plate, fill: NSColor(calibratedRed: 0.25, green: 0.28, blue: 0.34, alpha: 1), stroke: sp.outline, width: 1.6)
            // the reactor in its chest pulses, and blazes during a power move
            let c = bp(b, sx, 0.26)
            let pulse = mood == .power ? 1 : 0.6 + 0.4 * abs(sin(time * 2.2))
            let core = NSBezierPath(ovalIn: NSRect(x: c.x - 5.5, y: c.y - 5.5, width: 11, height: 11))
            paint(core, fill: sp.outline)
            sp.ink.withAlphaComponent(pulse).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - 3.6, y: c.y - 3.6, width: 7.2, height: 7.2)).fill()
            // hazard stripes on the shoulders
            NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.20, alpha: 1).setFill()
            for s in [CGFloat(-1), 1] {
                let o = bp(b, s * 0.88, 0.36)
                NSBezierPath(roundedRect: NSRect(x: o.x - 3.5, y: o.y, width: 7, height: 4), xRadius: 1, yRadius: 1).fill()
            }
        default:
            break
        }
    }

    // MARK: In front of the body

    func drawToughFront(_ ctx: CGContext, _ b: NSRect) {
        let sp = species
        guard sp != .shark else { return }
        // clawed feet that stomp
        var step: CGFloat = (mood == .walk || mood == .chase) ? sin(time * (mood == .chase ? 14 : walkRate)) : 0
        if vibing, mood != .walk { step = sin(beatPhase) * 0.8 }      // stomping to the beat
        for (i, dx) in ([-1, 1] as [CGFloat]).enumerated() {
            let up = max(0, i == 0 ? step : -step) * 4
            let r = NSRect(x: b.midX + dx * b.width * 0.21 - 9.5, y: b.minY - 3 + up, width: 19, height: 9)
            let rad: CGFloat = sp == .robot ? 2 : 4
            paint(NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad), fill: sp.foot, stroke: sp.outline, width: 2.4)
            guard sp != .robot else { continue }
            for k in [CGFloat(4), 9.5, 15] {
                let claw = NSBezierPath()
                claw.move(to: NSPoint(x: r.minX + k - 2.2, y: r.minY + 0.6))
                claw.line(to: NSPoint(x: r.minX + k, y: r.minY + 4.6))
                claw.line(to: NSPoint(x: r.minX + k + 2.2, y: r.minY + 0.6))
                claw.close(); claw.lineJoinStyle = .round
                paint(claw, fill: .white, stroke: sp.outline, width: 0.8)
            }
        }
        if sp == .dino {
            // famously tiny arms
            let excited = mood == .happy || mood == .dance || mood == .power || mood == .held
            for s in [CGFloat(-1), 1] {
                let wave = excited ? sin(time * 16 + s) * 3 : sin(time * 2 + s) * 0.6
                let o = bp(b, s * 0.58, 0.27)
                let arm = NSBezierPath()
                arm.move(to: o); arm.line(to: NSPoint(x: o.x + s * 9, y: o.y - 4 + wave))
                arm.lineCapStyle = .round
                paint(arm, fill: nil, stroke: sp.outline, width: 6.5)
                paint(arm, fill: nil, stroke: sp.fur, width: 2.6)
            }
        }
    }

    // MARK: Face

    func drawToughFace(_ b: NSRect) {
        let sp = species
        let eyeY = eyeLine(b)
        let fx = b.midX + faceShift
        let open = mood == .happy || mood == .held || mood == .stretch || mood == .dance || mood == .power
        let sad = mood == .sad
        let spread: CGFloat

        switch sp {
        case .wolf:
            spread = 13.5
            let muzzle = roundedPoly([NSPoint(x: fx - 17, y: eyeY - 7), NSPoint(x: fx + 17, y: eyeY - 7), NSPoint(x: fx + 12, y: eyeY - 21),
                                      NSPoint(x: fx, y: eyeY - 26), NSPoint(x: fx - 12, y: eyeY - 21)], radius: 3)
            paint(muzzle, fill: NSColor(calibratedRed: 0.87, green: 0.89, blue: 0.92, alpha: 1))
            let nose = roundedPoly([NSPoint(x: fx - 5.5, y: eyeY - 8.5), NSPoint(x: fx + 5.5, y: eyeY - 8.5), NSPoint(x: fx, y: eyeY - 14.5)], radius: 1.2)
            paint(nose, fill: sp.ink)
            toughMouth(NSPoint(x: fx, y: eyeY - 18), half: 9, open: open, fangs: !sad)
            // an old scar over one eye
            let ex = fx - spread
            let scar = NSBezierPath()
            scar.move(to: NSPoint(x: ex - 2.5, y: eyeY + 11)); scar.line(to: NSPoint(x: ex + 1.5, y: eyeY - 9))
            scar.lineCapStyle = .round
            paint(scar, fill: nil, stroke: NSColor(calibratedRed: 0.95, green: 0.66, blue: 0.66, alpha: 1), width: 1.9)

        case .dino:
            spread = 15
            let jawY = b.minY + b.height * 0.52
            let half = b.width / 2 * 0.80
            if open {
                // jaws apart
                let gap = NSBezierPath(roundedRect: NSRect(x: fx - half, y: jawY - 9, width: half * 2, height: 9), xRadius: 3, yRadius: 3)
                paint(gap, fill: NSColor(calibratedRed: 0.36, green: 0.07, blue: 0.10, alpha: 1), stroke: sp.outline, width: 2)
                teeth(from: fx - half + 2, to: fx + half - 2, y: jawY - 9, count: 7, length: -3.6)
            } else {
                let seam = NSBezierPath()
                seam.move(to: NSPoint(x: b.minX + 2, y: jawY)); seam.line(to: NSPoint(x: b.maxX - 2, y: jawY))
                paint(seam, fill: nil, stroke: sp.outline, width: 2)
            }
            teeth(from: fx - half + 2, to: fx + half - 2, y: jawY, count: 8, length: 5)
            sp.outline.setFill()
            for dx in [CGFloat(-4.5), 4.5] {
                NSBezierPath(ovalIn: NSRect(x: fx + dx - 1.3, y: eyeY - 11, width: 2.6, height: 3)).fill()
            }

        case .dragon:
            spread = 13
            let snout = roundedPoly([NSPoint(x: fx - 13, y: eyeY - 7), NSPoint(x: fx + 13, y: eyeY - 7),
                                     NSPoint(x: fx + 9, y: eyeY - 22), NSPoint(x: fx - 9, y: eyeY - 22)], radius: 3)
            paint(snout, fill: NSColor(calibratedRed: 0.84, green: 0.32, blue: 0.27, alpha: 1), stroke: sp.outline, width: 1.8)
            sp.outline.setFill()
            for dx in [CGFloat(-4.5), 4.5] {
                NSBezierPath(ovalIn: NSRect(x: fx + dx - 1.3, y: eyeY - 12, width: 2.6, height: 3)).fill()
            }
            toughMouth(NSPoint(x: fx, y: eyeY - 16.5), half: 7, open: open, fangs: !sad)

        case .robot:
            spread = 10.5
            // a visor that dips in the middle, like a permanent scowl
            let visor = roundedPoly([NSPoint(x: fx - 22, y: eyeY + 9), NSPoint(x: fx, y: eyeY + 5), NSPoint(x: fx + 22, y: eyeY + 9),
                                     NSPoint(x: fx + 22, y: eyeY - 7), NSPoint(x: fx - 22, y: eyeY - 7)], radius: 2.5)
            paint(visor, fill: NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.11, alpha: 1), stroke: sp.outline, width: 1.8)
            // a vent where a mouth would be; it glows when Bolt is pleased
            (open ? sp.ink : sp.outline).setStroke()
            for dx in [CGFloat(-5), 0, 5] {
                let v = NSBezierPath()
                v.move(to: NSPoint(x: fx + dx, y: eyeY - 11)); v.line(to: NSPoint(x: fx + dx, y: eyeY - (sad ? 14 : 16)))
                v.lineWidth = 2; v.lineCapStyle = .round; v.stroke()
            }

        default:
            // shark
            spread = 13
            let my = eyeY - 13
            let mw: CGFloat = 22
            if sad {
                let frown = NSBezierPath()
                frown.move(to: NSPoint(x: fx - 13, y: my - 9))
                frown.curve(to: NSPoint(x: fx + 13, y: my - 9), controlPoint1: NSPoint(x: fx - 6, y: my - 2), controlPoint2: NSPoint(x: fx + 6, y: my - 2))
                frown.lineCapStyle = .round
                paint(frown, fill: nil, stroke: sp.outline, width: 2.4)
            } else {
                let depth: CGFloat = open ? 25 : 15
                let mouth = NSBezierPath()
                mouth.move(to: NSPoint(x: fx - mw, y: my))
                mouth.curve(to: NSPoint(x: fx + mw, y: my), controlPoint1: NSPoint(x: fx - mw * 0.5, y: my - depth), controlPoint2: NSPoint(x: fx + mw * 0.5, y: my - depth))
                mouth.curve(to: NSPoint(x: fx - mw, y: my), controlPoint1: NSPoint(x: fx + mw * 0.5, y: my - 5), controlPoint2: NSPoint(x: fx - mw * 0.5, y: my - 5))
                mouth.close(); mouth.lineJoinStyle = .round
                paint(mouth, fill: NSColor(calibratedRed: 0.36, green: 0.07, blue: 0.12, alpha: 1))
                NSGraphicsContext.saveGraphicsState()
                mouth.addClip()
                // a row of teeth following the upper lip
                let n = 7
                let row = NSBezierPath()
                func lip(_ t: CGFloat) -> NSPoint { NSPoint(x: fx + t * mw, y: my - 3.75 * (1 - t * t) + 0.5) }
                row.move(to: lip(-1))
                for i in 0..<n {
                    let t0 = -1 + 2 * CGFloat(i) / CGFloat(n), t1 = -1 + 2 * CGFloat(i + 1) / CGFloat(n)
                    let m = lip((t0 + t1) / 2)
                    row.line(to: NSPoint(x: m.x, y: m.y - 6))
                    row.line(to: lip(t1))
                }
                row.line(to: NSPoint(x: fx + mw, y: my + 4)); row.line(to: NSPoint(x: fx - mw, y: my + 4))
                row.close(); row.lineJoinStyle = .round
                paint(row, fill: .white, stroke: sp.outline, width: 0.9)
                NSGraphicsContext.restoreGraphicsState()
                paint(mouth, fill: nil, stroke: sp.outline, width: 2.2)
            }
        }

        drawToughEyes(fx: fx, eyeY: eyeY, spread: spread)
        drawEyewear(fx: fx, spread: spread, eyeY: eyeY)
    }

    /// A row of pointed teeth hanging from (or, with a negative length, standing on) a line.
    func teeth(from x0: CGFloat, to x1: CGFloat, y: CGFloat, count: Int, length: CGFloat) {
        let w = (x1 - x0) / CGFloat(count)
        let p = NSBezierPath()
        p.move(to: NSPoint(x: x0, y: y))
        for i in 0..<count {
            p.line(to: NSPoint(x: x0 + (CGFloat(i) + 0.5) * w, y: y - length))
            p.line(to: NSPoint(x: x0 + CGFloat(i + 1) * w, y: y))
        }
        p.close(); p.lineJoinStyle = .round
        paint(p, fill: .white, stroke: species.outline, width: 0.9)
    }

    /// A tight-lipped snarl with two fangs, or an open mouth when the pet is excited.
    func toughMouth(_ c: NSPoint, half: CGFloat, open: Bool, fangs: Bool) {
        let ink = species.ink
        if open {
            openMouth(NSPoint(x: c.x, y: c.y - 1.5), half * 2 + 2, 7.5)
        } else {
            let m = NSBezierPath()
            m.move(to: NSPoint(x: c.x - half, y: c.y - 2.5)); m.line(to: NSPoint(x: c.x, y: c.y + 1)); m.line(to: NSPoint(x: c.x + half, y: c.y - 2.5))
            m.lineCapStyle = .round; m.lineJoinStyle = .round
            paint(m, fill: nil, stroke: ink, width: 2)
        }
        guard fangs else { return }
        for s in [CGFloat(-1), 1] {
            let x = c.x + s * half * 0.62
            let top = c.y + (open ? 1.2 : -1.2)
            let f = NSBezierPath()
            f.move(to: NSPoint(x: x - 1.9, y: top)); f.line(to: NSPoint(x: x, y: top - 5.2)); f.line(to: NSPoint(x: x + 1.9, y: top))
            f.close(); f.lineJoinStyle = .round
            paint(f, fill: .white, stroke: ink, width: 0.9)
        }
    }

    /// Narrow, slanted eyes under heavy brows.
    func drawToughEyes(fx: CGFloat, eyeY: CGFloat, spread: CGFloat) {
        let sp = species
        let mech = sp == .robot
        let blinking = fmod(time + 1.3, 4.3) < 0.12
        let sad = mood == .sad
        let heavy: CGFloat = sp == .dino || sp == .shark ? 4.2 : 3.6

        for dx in [CGFloat(-1), 1] {
            let ex = fx + dx * spread
            var brow: (NSPoint, NSPoint)? = (NSPoint(x: ex + dx * 9.5, y: eyeY + 9.5), NSPoint(x: ex - dx * 7, y: eyeY + 2.5))
            sp.ink.setStroke(); sp.ink.setFill()
            switch lostInMusic ? .happy : mood {     // a fierce grin, feeling the song
            case .sleep, .stretch:
                let lid = NSBezierPath()
                lid.move(to: NSPoint(x: ex + dx * 6, y: eyeY + 1)); lid.line(to: NSPoint(x: ex - dx * 5, y: eyeY - 2))
                lid.lineWidth = 2.5; lid.lineCapStyle = .round; lid.stroke()
                brow = (NSPoint(x: ex + dx * 8.5, y: eyeY + 7), NSPoint(x: ex - dx * 6, y: eyeY + 4))
            case .happy, .dance:
                // a fierce grin:  ^  ^
                let up = NSBezierPath()
                up.move(to: NSPoint(x: ex - 5.5, y: eyeY - 3)); up.line(to: NSPoint(x: ex, y: eyeY + 3)); up.line(to: NSPoint(x: ex + 5.5, y: eyeY - 3))
                up.lineWidth = 2.7; up.lineCapStyle = .round; up.lineJoinStyle = .round; up.stroke()
                brow = (NSPoint(x: ex + dx * 9, y: eyeY + 10.5), NSPoint(x: ex - dx * 6.5, y: eyeY + 6.5))
            case .dizzy:
                spiral(NSPoint(x: ex, y: eyeY), 6)
                brow = nil
            case .power:
                let squint = NSBezierPath()
                squint.move(to: NSPoint(x: ex - dx * 4.5, y: eyeY + 4.5))
                squint.line(to: NSPoint(x: ex + dx * 3, y: eyeY))
                squint.line(to: NSPoint(x: ex - dx * 4.5, y: eyeY - 4.5))
                squint.lineWidth = 2.6; squint.lineCapStyle = .round; squint.lineJoinStyle = .round; squint.stroke()
                brow = (NSPoint(x: ex + dx * 9.5, y: eyeY + 11), NSPoint(x: ex - dx * 7.5, y: eyeY + 5))
            case .held:
                // startled: wide and round
                let r = NSRect(x: ex - 5.5, y: eyeY - 5.5, width: 11, height: 11)
                paint(NSBezierPath(ovalIn: r), fill: sp == .shark ? .white : sp.iris, stroke: mech ? nil : sp.outline, width: 1.6)
                if !mech {
                    sp.ink.setFill()
                    NSBezierPath(ovalIn: NSRect(x: ex - 2, y: eyeY - 2, width: 4, height: 4)).fill()
                }
                brow = (NSPoint(x: ex + dx * 8, y: eyeY + 11.5), NSPoint(x: ex - dx * 5, y: eyeY + 10.5))
            default:
                if blinking {
                    let lid = NSBezierPath()
                    lid.move(to: NSPoint(x: ex + dx * 6, y: eyeY + 1)); lid.line(to: NSPoint(x: ex - dx * 5, y: eyeY - 2))
                    lid.lineWidth = 2.5; lid.lineCapStyle = .round; lid.stroke()
                } else if sp == .shark {
                    // small, flat, black
                    let r = NSRect(x: ex - 4.4 + gaze.x * 0.5, y: eyeY - 4.4 + gaze.y * 0.5, width: 8.8, height: 8.8)
                    NSBezierPath(ovalIn: r).fill()
                    NSColor.white.setFill()
                    NSBezierPath(ovalIn: NSRect(x: r.midX + 0.4, y: r.midY + 0.6, width: 2.6, height: 2.6)).fill()
                } else {
                    // a slanted wedge: high at the outer corner, low towards the nose (flipped when sad)
                    let outerTop = NSPoint(x: ex + dx * 7, y: eyeY + (sad ? 0.5 : 4.5))
                    let innerTop = NSPoint(x: ex - dx * 6, y: eyeY + (sad ? 3.5 : -0.5))
                    let eye = roundedPoly([outerTop, innerTop, NSPoint(x: ex - dx * 5, y: eyeY - 5.5), NSPoint(x: ex + dx * 6, y: eyeY - 4.5)], radius: 1.2)
                    paint(eye, fill: sp.iris, stroke: mech ? nil : sp.outline, width: 1.6)
                    let px = ex + gaze.x * 0.9
                    sp.ink.setFill(); sp.ink.setStroke()
                    if sp == .wolf {
                        NSBezierPath(ovalIn: NSRect(x: px - 2.3, y: eyeY - 3.6 + gaze.y * 0.4, width: 4.6, height: 4.6)).fill()
                    } else if !mech {
                        let slit = NSBezierPath()
                        slit.move(to: NSPoint(x: px, y: eyeY + 1.6)); slit.line(to: NSPoint(x: px, y: eyeY - 3.8))
                        slit.lineWidth = 2.3; slit.lineCapStyle = .round; slit.stroke()
                    }
                }
                if sad { brow = (NSPoint(x: ex + dx * 9, y: eyeY + 5.5), NSPoint(x: ex - dx * 6, y: eyeY + 9)) }
            }
            if let brow, !mech {
                let p = NSBezierPath()
                p.move(to: brow.0); p.line(to: brow.1)
                p.lineCapStyle = .round
                paint(p, fill: nil, stroke: sp.outline, width: heavy)
            }
        }
    }
}
