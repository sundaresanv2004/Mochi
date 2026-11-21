import Foundation

/// The built-in brain, with a language model chiming in every few minutes.
///
/// `nextDecision` has to answer straight away (it runs inside the 30fps loop), so the model is never
/// waited for: a question goes out in the background, and whatever comes back is used for the *next*
/// decision. With AI off, unreachable or slow, this behaves exactly like `MindBrain`.
final class LLMBrain: Brain {
    private let base = MindBrain()
    private var idea: (decision: Decision, at: Date)?
    private var asking = false
    private var nextAsk = Date().addingTimeInterval(.random(in: 45...90))
    private var recent: [String] = []

    func nextDecision(_ ctx: PetContext) -> Decision {
        let ai = PetAI.shared
        guard ai.on(.brain) else { return base.nextDecision(ctx) }

        // Moments when the pet must stay calm or asleep belong to the built-in rules.
        let handsOff = ctx.userAway || ctx.focusing || ctx.media == .call || ctx.energy < 0.08
        let now = Date()
        if let i = idea {
            idea = nil
            let age = now.timeIntervalSince(i.at)
            if !handsOff, age < 45 {
                var d = i.decision
                d.source = "AI model"
                return remember(d)
            }
            DebugLog.add(.ai, "Dropped the model's idea (\(i.decision.action.label(on: ctx.surface))): "
                         + (handsOff ? "the pet has to stay calm right now" : "it came \(Int(age))s ago, too late"),
                         pet: ctx.species.name)
        }
        if !handsOff, !asking, now >= nextAsk {
            asking = true
            ai.decide(ctx, recent: recent) { [weak self] d in
                guard let self else { return }
                self.asking = false
                self.nextAsk = Date().addingTimeInterval(.random(in: 150...300))
                if let d { self.idea = (d, Date()) }
            }
        }
        return remember(base.nextDecision(ctx))
    }

    private func remember(_ d: Decision) -> Decision {
        recent.append(String(describing: d.action).components(separatedBy: "(")[0])
        if recent.count > 6 { recent.removeFirst() }
        return d
    }
}
