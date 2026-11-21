import Foundation

/// Where the pet is currently attached.
enum Surface { case floor, leftWall, rightWall, ceiling, air }

/// What the pet can do. Add new behaviors here, then handle them in PetController + PetView.
enum PetAction: Equatable {
    case idle
    case walk(axis: CGFloat)   // +1 / -1 along the current surface (right/up), set when chosen
    case sleep
    case chase                 // follow the cursor
    case happy
    case greet                 // hop + say something
    case leap                  // jump up onto a window
    case stretch               // big yawn + stretch
    case spin                  // a full twirl
    case dance                 // wiggle with music notes
    case lookAround            // glance left and right
    case zoomies               // sprint back and forth
    case climbEdge             // walk to the nearest screen edge on purpose and climb it
    case dizzy                 // spiral eyes after the cursor is shaken at it
    case mope                  // sits there looking sad (hungry or lonely)
    case hide                  // sneak to the screen edge, duck behind it, then peek out
    case visit                 // run over to the other pet and say hi
    case power                 // signature move: fire, lasers, a mighty roar…
    case flip                  // a backflip
}

struct Decision {
    let action: PetAction
    let duration: TimeInterval
    /// Something to say while starting the action (optional).
    var line: String? = nil
    /// Who chose it ("instincts", "AI model"), for the Debug page's event log.
    var source: String? = nil
}

/// Everything the brain is allowed to know about the world.
struct PetContext {
    let surface: Surface
    let axisFraction: CGFloat          // 0...1 position along the current surface
    let cursorDistance: CGFloat
    let secondsSinceInteraction: TimeInterval
    let hour: Int
    let platformAbove: Bool            // a window is within leaping reach
    let canClimb: Bool                 // on the Dock floor with climbing enabled
    let canHide: Bool                  // on the Dock floor with a screen edge to duck behind
    let media: MediaActivity           // what is playing on the Mac
    let userAway: Bool                 // nobody has touched the Mac for a while
    let focusing: Bool                 // a focus session is running: keep calm
    let species: Species
    let energy: Double                 // 0...1, the pet's needs (see PetMind)
    let fullness: Double
    let joy: Double
    let bondLevel: Int
}

/// Anything that can pick the next Decision.
/// `MindBrain` is the built-in instincts; `LLMBrain` (AI/LLMBrain.swift) lets a model chime in on top of it.
protocol Brain {
    func nextDecision(_ ctx: PetContext) -> Decision
}

/// Needs-driven behavior, no AI. What the pet does depends on what is going on around it
/// (music, calls, focus), how it feels (tired, hungry, lonely, joyful) and its species' personality.
final class MindBrain: Brain {
    private var lastNeedLine = Date.distantPast

    func nextDecision(_ ctx: PetContext) -> Decision {
        var d = choose(ctx)
        d.source = "instincts"
        return d
    }

    private func choose(_ ctx: PetContext) -> Decision {
        if ctx.userAway { return Decision(action: .sleep, duration: 30) }

        let p = ctx.species.personality
        let late = ctx.hour >= 23 || ctx.hour < 6
        // Sleepy late at night, or when nobody has played with it for a good while (not just a few minutes).
        let drowsy = ctx.secondsSinceInteraction > 1200 || late
        let tired = ctx.energy < 0.25
        let hungry = ctx.fullness < 0.2
        let lonely = ctx.joy < 0.25
        let joyful = ctx.joy > 0.7
        let quiet = ctx.media == .call || ctx.focusing

        // Running on empty: nothing else matters until it has had a nap.
        if ctx.energy < 0.08 {
            return Decision(action: .sleep, duration: .random(in: 40...80), line: needLine(Dialogue.sleepy, quiet: quiet))
        }

        var axis: CGFloat = Bool.random() ? 1 : -1
        if ctx.axisFraction < 0.12 { axis = 1 }
        if ctx.axisFraction > 0.88 { axis = -1 }

        func d(_ a: PetAction, _ lo: TimeInterval, _ hi: TimeInterval) -> Decision {
            Decision(action: a, duration: .random(in: lo...hi))
        }
        var o: [(Double, Decision)] = []

        if quiet {
            // On a call or in a focus session: stay quiet and mostly still.
            // On a call it says nothing but still potters about; in a focus session it mostly stays put.
            o = [(10, d(.idle, 4, 8)), (2, d(.lookAround, 2, 3))]
            o.append((ctx.focusing ? 2 : 9, d(.walk(axis: axis), 2, 5)))
            if drowsy || tired { o.append((3, d(.sleep, 10, 20))) }
        } else {
            switch ctx.media {
            case .video:
                // Watching along.
                o = [(9, d(.idle, 5, 10)), (2, d(.lookAround, 2, 3)), (1, d(.stretch, 2, 3))]
                if drowsy || tired { o.append((3, d(.sleep, 10, 20))) }

            case .none, .call, .music, .other:
                // Music doesn't change what it does, only how: it goes about its usual day while vibing
                // to the beat (PetView draws the groove), and now and then breaks into a proper dance.
                if ctx.surface == .floor || ctx.surface == .air {
                    o = [(4, d(.idle, 2, 5)), (10, d(.walk(axis: axis), 2, 7)), (1.5, d(.happy, 1.5, 1.5)),
                         (2, d(.stretch, 2.4, 2.4)), (1.5, d(.spin, 0.9, 0.9)), (1.5, d(.dance, 4, 4)),
                         (2.5, d(.lookAround, 3, 3)), (1.5, d(.zoomies, 3.5, 3.5)),
                     (1.2, d(.power, 2.2, 2.2)), (1.2, d(.flip, 0.8, 0.8))]
                } else {
                    // Clinging to an edge: it's mostly busy climbing around.
                    o = [(3, d(.idle, 2, 4)), (14, d(.walk(axis: axis), 3, 9)), (1.5, d(.lookAround, 2, 3)),
                         (1, d(.happy, 1.5, 1.5)), (1, d(.stretch, 2.4, 2.4))]
                }
                if ctx.cursorDistance < 500 { o.append((4, d(.chase, 3, 6))) }
                if drowsy { o.append((3, d(.sleep, 8, 20))) } else if tired { o.append((3, d(.sleep, 15, 30))) }
                if ctx.media == .music || ctx.media == .other, ctx.surface == .floor {
                    o.append((ctx.media == .music ? 2.5 : 1, d(.dance, 4, 7)))
                }
            }

            if ctx.platformAbove && ctx.surface == .floor {
                o.append((3, Decision(action: .leap, duration: 2)))
            }
            if ctx.canHide && ctx.media != .video {
                o.append((1.6, d(.hide, 14, 16)))
            }
            if ctx.canClimb && ctx.media != .video {
                o.append((3.5, d(.climbEdge, 10, 14)))
            }
            // Unmet needs: sit and sulk, and now and then say what's wrong.
            if hungry || lonely {
                let lines = hungry ? Dialogue.hungry(ctx.species) : Dialogue.lonely
                o.append((2.5, Decision(action: .mope, duration: .random(in: 3...5), line: needLine(lines, quiet: false))))
            }
        }

        // Feelings and personality tilt the odds.
        func factor(_ a: PetAction) -> Double {
            switch a {
            case .sleep:
                return p.sleepy * (tired ? 4 : 1) * (ctx.energy > 0.8 && !late ? 0.4 : 1)
            case .dance, .zoomies, .spin, .hide, .power, .flip:
                return p.playful * (joyful ? 1.6 : 1) * (tired ? 0.2 : 1) * (lonely || hungry ? 0.7 : 1)
            case .happy:
                return joyful ? 1.8 : (lonely || hungry ? 0.6 : 1)
            case .chase:
                return p.cuddly * (lonely ? 2 : 1) * (tired ? 0.4 : 1) * (ctx.bondLevel >= 3 ? 1.3 : 1)
            case .lookAround, .climbEdge, .leap:
                return p.curious * (tired ? 0.4 : 1)
            case .walk:
                return tired ? 0.5 : 1
            default:
                return 1
            }
        }
        o = o.map { ($0.0 * factor($0.1.action), $0.1) }

        let total = o.reduce(0) { $0 + $1.0 }
        var roll = Double.random(in: 0..<total)
        for (w, dec) in o {
            roll -= w
            if roll < 0 { return dec }
        }
        return o[0].1
    }

    /// A complaint, at most once every couple of minutes so it never nags.
    private func needLine(_ lines: [String], quiet: Bool) -> String? {
        let now = Date()
        guard !quiet, now.timeIntervalSince(lastNeedLine) > 120 else { return nil }
        lastNeedLine = now
        return lines.randomElement()
    }
}
