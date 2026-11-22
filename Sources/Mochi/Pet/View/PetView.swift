#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

enum Mood { case idle, walk, sleep, happy, chase, held, jump, dance, stretch, dizzy, sad, power }

struct Heart {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var age: CGFloat      // negative = waiting to appear
}

/// Draws the pet with Core Graphics (no image assets) and forwards mouse input.
final class PetView: NSView {
    /// The pet is drawn on a 120pt design canvas and scaled to whatever size the view is.
    static let side: CGFloat = 120
    static let size = NSSize(width: side, height: side)
    static let canvas = NSRect(origin: .zero, size: size)

    var species: Species = .mochi
    var mood: Mood = .idle
    var facing: CGFloat = 1              // local: +1 = looking right
    var time: CGFloat = 0
    var angle: CGFloat = 0               // radians; rotates the pet onto walls / ceiling
    var spin: CGFloat = 0                // extra twirl / wobble around the pet's own centre
    var gaze: CGPoint = .zero            // where the eyes look (local coordinates)
    var musicBpm: CGFloat = 0            // > 0 while music plays: headphones + bobbing to the beat
    var act: MediaAct?                   // what it's doing while something plays: DJing, binge-watching… (View/Acts)
    var outfit: Outfit = .none           // what the pet is wearing
    var sweat = false                    // the Mac is working hard
    var shiver = false                   // the battery is nearly empty
    var hop: CGFloat = 0                 // extra height off the ground (backflips)
    var tap: CGFloat = 0                 // 1 right after a key press, fades fast: a little bop while you type
    var impact: CGFloat = 0              // 1 right after landing, fades fast: a squash on touchdown
    var isPreview = false                // settings-panel mini version

    var onClick: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?

    var hearts: [Heart] = []
    var dragged = false
    var previewTimer: Timer?

    // MARK: Vibing to music

    /// Music is playing and the pet is going about its business (standing, walking, sulking):
    /// instead of stopping to dance, it grooves along to the beat.
    var vibing: Bool { musicBpm > 0 && (mood == .idle || mood == .walk || mood == .sad) }

    /// Angular speed of the walk cycle. While music plays the footsteps follow the tempo
    /// (two steps per beat, about the normal pace at 100–126 bpm).
    var walkRate: CGFloat { musicBpm > 0 ? 2 * .pi * musicBpm / 60 : 10 }

    /// Phase of the music: `abs(sin(beatPhase))` peaks once per beat, `sin(beatPhase)` swings
    /// left and right over two beats.
    var beatPhase: CGFloat { time * .pi * musicBpm / 60 }

    /// Every so often a vibing pet closes its eyes and gets lost in the song for a few seconds.
    /// Singing karaoke, it closes them for the big notes.
    var lostInMusic: Bool {
        if act == .karaoke, showsAct, mood == .idle { return fmod(time, 5) > 2.6 }
        return vibing && mood != .sad && fmod(time, 9) > 6
    }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { isPreview ? nil : super.hitTest(point) }

    // MARK: Animation clock

    func advance(_ dt: CGFloat) {
        time += dt
        tap = max(0, tap - dt * 7)
        impact = max(0, impact - dt * 5)
        for i in hearts.indices {
            hearts[i].age += dt
            if hearts[i].age > 0 { hearts[i].y += 36 * dt }
        }
        hearts.removeAll { $0.age > 1.1 }
    }

    func spawnHearts(_ n: Int) {
        for i in 0..<n {
            hearts.append(Heart(x: Self.canvas.midX + .random(in: -24...24), y: 70 + .random(in: 0...10),
                                size: .random(in: 5...8), age: -CGFloat(i) * 0.15))
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        previewTimer?.invalidate()
        previewTimer = nil
        guard isPreview, window != nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.previewTick() }
        RunLoop.main.add(t, forMode: .common)
        previewTimer = t
    }

    func previewTick() {
        guard window?.isVisible == true, window?.occlusionState.contains(.visible) == true else { return }
        advance(1.0 / 30.0)
        let phase = fmod(time, 12)
        if phase < 4 { mood = .idle } else if phase < 7 { mood = .walk }
        else if phase < 9 { mood = .happy } else if phase < 11 { mood = .dance } else { mood = .sleep }
        facing = fmod(time, 24) < 12 ? 1 : -1
        needsDisplay = true
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) { dragged = false }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        if !dragged { dragged = true; onDragBegan?() }
        var o = window.frame.origin
        o.x += event.deltaX
        o.y -= event.deltaY
        window.setFrameOrigin(o)
    }

    override func mouseUp(with event: NSEvent) {
        if dragged { onDragEnded?() } else { onClick?() }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.scaleBy(x: bounds.width / Self.side, y: bounds.height / Self.side)
        ctx.saveGState()
        if shiver, mood != .sleep { ctx.translateBy(x: sin(time * 46) * 1.1, y: 0) }
        if actShake != 0 { ctx.translateBy(x: actShake, y: 0) }
        ctx.translateBy(x: Self.canvas.midX, y: Self.canvas.midY)
        ctx.rotate(by: angle)
        ctx.translateBy(x: -Self.canvas.midX, y: -Self.canvas.midY)
        if spin != 0 {
            ctx.translateBy(x: Self.canvas.midX, y: 36)
            ctx.rotate(by: spin)
            ctx.translateBy(x: -Self.canvas.midX, y: -36)
        }
        var sway: CGFloat = 0
        if mood == .dance { sway = sin(time * 8) * 0.14 }
        else if mood == .walk || mood == .chase {
            // Rock from foot to foot and lean into the walk; tough pets stomp, the penguin waddles.
            let rock: CGFloat = species == .penguin ? 0.12 : (species.style == .tough ? 0.06 : 0.035)
            let lean: CGFloat = mood == .chase ? 0.10 : 0.04
            sway = sin(time * (mood == .chase ? 14 : walkRate)) * rock - facing * lean
        }
        // Grooving along: a gentle side-to-side sway in time with the music.
        if vibing { sway += sin(beatPhase) * (mood == .walk ? 0.05 : 0.08) }
        sway += actSway
        if sway != 0 {
            ctx.translateBy(x: Self.canvas.midX, y: 8)
            ctx.rotate(by: sway)
            ctx.translateBy(x: -Self.canvas.midX, y: -8)
        }
        drawPet(ctx)
        ctx.restoreGState()
        drawHearts()
        ctx.restoreGState()
    }
}
