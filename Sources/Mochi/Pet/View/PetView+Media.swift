#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// The kind of thing the pet is watching or listening to, as far as drawing goes (the details of each act
/// are in View/Acts; headphones for music are in PetView+Effects).
enum MediaGear: Equatable {
    case none
    case podcast    // one earbud in, nodding along, thinking dots now and then
    case video      // sitting in the flicker of the screen's light
    case movie      // 3D glasses, a bucket of popcorn and the screen's light

    /// The screen's light falls on the pet.
    var glows: Bool { self == .video || self == .movie }
}

/// Drawing the watching and listening gear.
extension PetView {
    /// What kind of thing is on, from the act.
    var watching: MediaGear {
        switch act?.kind {
        case .podcast: return .podcast
        case .video: return .video
        case .movie: return .movie
        default: return .none
        }
    }

    /// Whether the act's props are out right now: not asleep, held or mid-air, the right way up, and props
    /// that stand on the ground only while it stands still.
    var showsAct: Bool {
        guard let act, abs(angle) < 0.3 else { return false }
        switch mood {
        case .idle, .sad: return true
        case .walk, .chase: return !act.staysPut
        default: return false
        }
    }

    // MARK: The screen's light

    /// A soft, shifting light over the front of the body, like the glow of a screen in a dark room.
    /// Drawn while the body is the clip, so it stays on the pet.
    func drawScreenGlow(_ body: NSRect) {
        guard watching.glows, mood != .sleep else { return }
        // Two slow waves make a flicker that never quite repeats: scenes changing.
        let flicker = 0.5 + 0.5 * sin(time * 2.3) * sin(time * 0.9 + 1)
        let cool = NSColor(calibratedRed: 0.55, green: 0.75, blue: 1.0, alpha: 1)
        let warm = NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.55, alpha: 1)
        // Mostly the cool light of a screen, warming a little now and then as the scene changes.
        let tint = cool.blended(withFraction: CGFloat(0.15 + 0.15 * sin(time * 0.37)), of: warm) ?? cool
        let strength: CGFloat = watching == .movie ? 0.26 : 0.22
        let g = NSGradient(starting: tint.withAlphaComponent(strength + CGFloat(flicker) * 0.16),
                           ending: tint.withAlphaComponent(strength * 0.25))
        // Brightest on the side facing the screen (towards the viewer, so the middle of the face).
        g?.draw(in: NSBezierPath(ovalIn: body.insetBy(dx: -body.width * 0.15, dy: -body.height * 0.1)),
                relativeCenterPosition: NSPoint(x: facing * 0.15, y: 0.25))
    }

    /// The screen, reflected as a small bright rectangle in each eye while watching a video.
    /// (During a film the 3D glasses are in the way.)
    func drawScreenReflection(fx: CGFloat, spread: CGFloat, eyeY: CGFloat) {
        guard watching == .video, mood == .idle || mood == .walk || mood == .sad else { return }
        let flicker = CGFloat(0.75 + 0.25 * sin(time * 3.1))
        for dx in [CGFloat(-1), 1] {
            let r = NSRect(x: fx + dx * spread + gaze.x * 0.6 - 2.6, y: eyeY + gaze.y * 0.6 - 0.6, width: 5.2, height: 3.6)
            NSColor(calibratedRed: 0.80, green: 0.92, blue: 1.0, alpha: 0.95 * flicker).setFill()
            NSBezierPath(roundedRect: r, xRadius: 0.8, yRadius: 0.8).fill()
        }
    }
}
