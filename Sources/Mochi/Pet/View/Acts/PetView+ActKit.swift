#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// What every act is drawn with: where the face is, a paw in the pet's own colours, a drawing frame that
/// turns with the pet, timing helpers, and the hooks the body and face call (one place, so each act file
/// only has to draw its own props).
extension PetView {
    // MARK: Hooks called while drawing the pet

    /// Draws the act's props, in front of the body and face.
    func drawAct(_ body: NSRect) {
        guard let act, showsAct else { return }
        switch act {
        case .dj: drawDJ(body)
        case .airGuitar: drawAirGuitar(body)
        case .karaoke: drawKaraoke(body)
        case .rave: drawRave(body)
        case .bongos: drawBongos(body)
        case .earbud: drawEarbud(body)
        case .notes: drawNotepad(body)
        case .coffee: drawCoffee(body)
        case .radio: drawRadio(body)
        case .thinker: drawThinker(body)
        case .phone: drawPhone(body)
        case .snacks: drawSnacks(body)
        case .like: drawLikeSign(body)
        case .subscribe: drawSubscribe(body)
        case .comments: drawComments(body)
        case .cinema: drawPopcorn(body)
        case .blanket: drawBlanket(body)
        case .soda: drawSoda(body)
        case .scary: drawCushion(body)
        case .tearjerker: drawTissues(body)
        case .spy, .masquerade, .peekaboo, .sleepMask, .turnAway: drawPrivacy(body)
        }
    }

    /// Things on or over the eyes. Returns true when they replace the pet's own eyewear (3D glasses).
    func drawActEyes(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) -> Bool {
        drawScreenReflection(fx: fx, spread: spread, eyeY: eyeY)
        guard let act, mood != .sleep else { return false }
        if act.isPrivacy, showsAct { return drawPrivacyEyes(fx: fx, spread: spread, eyeY: eyeY) }
        switch act {
        case .cinema:
            draw3DGlasses(fx: fx, spread: spread, eyeY: eyeY)
            return true
        case .tearjerker where showsAct:
            drawTears(fx: fx, spread: spread, eyeY: eyeY)
        default:
            break
        }
        return false
    }

    /// Light falling on the body (drawn while the body is the clip): the screen's glow, rave lights.
    func drawActLight(_ body: NSRect) {
        drawBackFur(body)
        drawScreenGlow(body)
        if act == .rave, showsAct { drawRaveLight(body) }
    }

    /// Extra height for the act's pose: nodding along, leaning in.
    var actLift: CGFloat {
        guard let act, showsAct, mood == .idle || mood == .sad else { return 0 }
        switch act {
        case .earbud: return abs(sin(time * 2.1)) * 1.8
        case .thinker: return (sin(time * 1.3) + 1) * 0.8
        case .scary: return scaredJump * 4
        default: return 0
        }
    }

    /// Extra squash for the act's pose: chewing.
    var actSquash: CGFloat {
        guard let act, showsAct, mood == .idle else { return 0 }
        switch act {
        case .cinema, .snacks, .soda: return chewing ? sin(time * 20) * 0.02 : 0
        default: return 0
        }
    }

    /// Leaning (radians, added to the body's sway): in towards the radio.
    var actSway: CGFloat {
        guard act == .radio, showsAct, mood == .idle else { return 0 }
        return -facing * (0.06 + 0.02 * sin(time * 1.7))
    }

    /// A shiver (points of sideways shake): the scary bit.
    var actShake: CGFloat {
        guard act == .scary, showsAct else { return 0 }
        return sin(time * 48) * 1.3 * scaredJump
    }

    /// Chewing, just after something went in.
    var chewing: Bool {
        switch act {
        case .cinema: let t = fmod(time, 4.2); return t > 0.7 && t < 1.6
        case .snacks: let t = fmod(time, 5); return t > 1.45 && t < 2.4
        default: return false
        }
    }

    // MARK: Where things are

    /// The middle of the face, a little towards where the pet is looking.
    func faceX(_ body: NSRect) -> CGFloat {
        if species.style == .tough { return body.midX + faceShift }
        return body.midX + facing * (species == .mochi ? 6 : 5)
    }

    /// Roughly where the mouth is.
    func mouthPoint(_ body: NSRect) -> NSPoint {
        let drop: CGFloat = species.style == .tough ? (species == .robot ? 14 : 17) : (species == .ghost ? 7 : 10)
        return NSPoint(x: faceX(body), y: eyeLine(body) - drop)
    }

    /// Where a paw would be holding something at the pet's side (+1: the side it faces).
    func handPoint(_ body: NSRect, side: CGFloat, height: CGFloat = 0.32) -> NSPoint {
        NSPoint(x: body.midX + facing * side * (body.width / 2 - 7), y: body.minY + body.height * height)
    }

    /// The floor in front of the pet's feet: props that stand on the ground sit here and don't bounce with it.
    /// The ghost floats, so its props float along with it.
    func groundY(_ body: NSRect) -> CGFloat { species == .ghost ? body.minY - 2 : 5 }

    // MARK: Drawing helpers

    func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    }

    /// Fill and outline in one go.
    func paint(_ path: NSBezierPath, _ fill: NSColor?, _ stroke: NSColor? = nil, _ width: CGFloat = 1.2) {
        if let fill { fill.setFill(); path.fill() }
        if let stroke { stroke.setStroke(); path.lineWidth = width; path.lineJoinStyle = .round; path.stroke() }
    }

    func roundRect(_ r: NSRect, _ radius: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius) }

    func circle(_ c: NSPoint, _ r: CGFloat) -> NSBezierPath { NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }

    /// A dark outline that goes with any prop.
    var ink: NSColor { rgb(0.20, 0.16, 0.20) }

    /// A little paw in the pet's own colours, holding or tapping something.
    func paw(_ p: NSPoint, _ r: CGFloat = 4.4) {
        let fill = species.style == .tough ? species.fur.blended(withFraction: 0.12, of: .black) ?? species.fur : species.fur
        paint(NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r * 0.85, width: r * 2, height: r * 1.7)), fill, species.outline, 1.6)
    }

    /// Draws in a frame at `origin` that faces the way the pet does: +x is "forward". `angle` tilts it,
    /// `scale` sizes the prop up or down.
    func local(_ origin: NSPoint, angle: CGFloat = 0, scale: CGFloat = 1, _ draw: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: origin.x, yBy: origin.y)
        if facing < 0 { t.scaleX(by: -1, yBy: 1) }
        t.rotate(byRadians: angle)
        if scale != 1 { t.scale(by: scale) }
        t.concat()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Progress 0…1 of something that happens once every `every` seconds and lasts `lasting`, or nil
    /// between times. `offset` staggers several of them.
    func moment(every: CGFloat, lasting: CGFloat, offset: CGFloat = 0) -> CGFloat? {
        let t = fmod(time + offset, every)
        return t < lasting ? t / lasting : nil
    }

    /// 0…1, peaking once per beat (the song's tempo, or a steady 110 bpm).
    var beatPulse: CGFloat {
        let bpm = musicBpm > 0 ? musicBpm : 110
        return abs(sin(time * .pi * bpm / 60))
    }

    /// Text that reads the right way round whichever way the pet faces.
    func label(_ s: String, at p: NSPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .heavy, centred: Bool = true) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
        let str = s as NSString
        let w = str.size(withAttributes: attrs)
        // Keep it inside the pet's window, whichever side it floats off to.
        let left = min(max(centred ? p.x - w.width / 2 : p.x, 1), Self.side - w.width - 1)
        str.draw(at: NSPoint(x: left, y: p.y - w.height / 2), withAttributes: attrs)
    }

    /// Fades in over the first 15% and out over the last 25% of `t` (0…1).
    func fade(_ t: CGFloat) -> CGFloat { min(1, t / 0.15) * min(1, (1 - t) / 0.25) }
}
