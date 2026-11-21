import AppKit

/// What two pets can get up to together.
enum SocialKind: String, CaseIterable, Identifiable {
    case greet, chat, tag, dance, follow, showOff, nap, jealous

    var id: String { rawValue }

    var label: String {
        switch self {
        case .greet: return "Say hello"
        case .chat: return "Have a chat"
        case .tag: return "Play tag"
        case .dance: return "Dance together"
        case .follow: return "Follow the leader"
        case .showOff: return "Show off"
        case .nap: return "Nap together"
        case .jealous: return "Jealous of petting"
        }
    }
}

/// Where a pet is in a get-together. The one who started it drives; the other waits, then joins in.
enum SocialPhase {
    case none
    case approach       // running over to the other pet
    case wait           // standing still, watching the other one come
    case flee, pursue   // tag
    case lead, trail    // follow the leader
}

/// Two pets: meeting up, playing together, keeping out of each other's way.
///
/// Every get-together runs under the `.visit` action on both pets, so the brain leaves them alone
/// until it is over. Anything else that takes a pet's attention (a click, music starting, a reminder)
/// changes its action, which ends the get-together for both.
extension PetController {
    /// Standing on the Dock / screen bottom, where get-togethers happen.
    var onDock: Bool { surface == .floor && platform.id == 0 && jump == nil && !held }

    /// Free to start something with the other pet.
    var sociable: Bool {
        canAct && action != .sleep && !userAway && media != .call && !focusing && treat == nil && ball == nil
            && slipTimer <= 0 && hidePhase == .none
    }

    func maybeVisit(_ dt: CGFloat) {
        guard let b = buddy else { return }
        stepAside(b)
        visitWait -= TimeInterval(dt)
        guard visitWait <= 0, social == .none else { return }
        if chatIsStale { banterLines = nil; chatReady = nil }
        let forced = forcedSocial != nil

        // The other one is already having a conversation written for the two of them: let that one lead.
        guard !b.banterAsked, b.chatReady == nil else { visitWait = 10; return }
        guard sociable, b.canAct, !b.userAway, b.social == .none, b.treat == nil, b.ball == nil else {
            visitWait = 6
            return
        }
        // They can only meet on the ground: whoever is up a wall, on the ceiling or on a window comes down first.
        guard onDock else {
            if forced || Bool.random() { comeDown() }
            visitWait = 4
            return
        }
        guard b.onDock else {
            if forced || (b.action != .sleep && Bool.random()) {
                say(Dialogue.comeDown(b.species.name).randomElement() ?? "Come down!")
                if forced, b.action == .sleep { b.action = .idle; b.remaining = 1 }
                b.comeDown()
            }
            visitWait = 4
            return
        }
        // On different displays: go over to where the other one is first.
        guard currentScreen == b.currentScreen else {
            crossToward(b)
            visitWait = 3
            return
        }
        if forced, b.action == .sleep, forcedSocial != .nap { b.action = .idle; b.remaining = 1 }

        // A chat whose words are ready goes first, unless the other one has dozed off meanwhile.
        if chatReady != nil, forcedSocial == nil {
            if b.action == .sleep { banterLines = nil; chatReady = nil } else { forcedSocial = .chat }
        }
        visitWait = .random(in: 40...90)
        b.visitWait = max(b.visitWait, 20)
        let kind = forcedSocial ?? pickSocial(b)
        forcedSocial = nil
        // The model writes the chat first; they get together once it is ready (see orderChat).
        if kind == .chat, chatReady == nil, PetAI.shared.on(.banter) {
            if !banterAsked { orderChat(with: b) }
            return
        }
        beginSocial(kind, with: b)
    }

    func pickSocial(_ b: PetController) -> SocialKind {
        if b.action == .sleep { return .nap }               // don't wake it: curl up next to it
        var options: [(Double, SocialKind)] = [(3, .greet), (2, .dance), (2, .follow), (2, .showOff)]
        if PetAI.shared.on(.banter) { options.append((4, .chat)) }
        if mind.energy > 0.3 { options.append((3, .tag)) }
        if mind.energy < 0.3 || hour >= 22 || hour < 6 { options.append((4, .nap)) }
        var roll = Double.random(in: 0..<options.reduce(0) { $0 + $1.0 })
        for (weight, kind) in options {
            roll -= weight
            if roll < 0 { return kind }
        }
        return .greet
    }

    func beginSocial(_ kind: SocialKind, with b: PetController) {
        apply(Decision(action: .visit, duration: 40), why: "two pets")
        DebugLog.add(.social, "Starts \(kind.label.lowercased()) with \(b.species.name)", pet: species.name)
        socialKind = kind
        social = .approach
        socialTimer = 12
        // The other pet stops and waits, unless it is asleep or simply being petted.
        let joining = kind != .jealous && !(kind == .nap && b.action == .sleep)
        if kind == .greet { prepareBanter(with: b) }
        if joining {
            b.invited(by: self)
            if Double.random(in: 0..<1) < 0.5 { say(Dialogue.calling(b.species.name).randomElement() ?? "Hey!") }
        }
    }

    func invited(by b: PetController) {
        apply(Decision(action: .visit, duration: 40), why: "two pets")
        social = .wait
        socialTimer = 14
        facing = b.cx > cx ? 1 : -1
    }

    func endSocial(cheer: Bool = false) {
        social = .none
        guard action == .visit else { return }
        DebugLog.add(.social, "Get-together over\(cheer ? ", cheering" : "")", pet: species.name)
        action = cheer ? .happy : .idle
        remaining = cheer ? 1.6 : 1
    }

    /// Runs every frame while the pet is busy with the other one.
    func visitBuddy(_ dt: CGFloat, _ f: NSRect) {
        guard social != .none, onDock, let b = buddy, b.onDock else { endSocial(); return }
        socialTimer -= dt
        let d = b.cx - cx
        let toward: CGFloat = d >= 0 ? 1 : -1

        switch social {
        case .none:
            break

        case .approach:
            let joining = socialKind != .jealous && !(socialKind == .nap && b.action == .sleep)
            if socialTimer <= 0 || (joining && b.social != .wait) { endSocial(); return }
            facing = toward
            if abs(d) > 62 * scale {
                view.mood = .chase
                advance(chaseSpeed * 0.85 * dt, autonomous: false, f)
            } else {
                arrive(b)
            }

        case .wait:
            view.mood = .idle
            facing = toward
            if socialTimer <= 0 || b.social == .none { endSocial() }

        case .flee:
            guard b.social == .pursue else { endSocial(cheer: true); return }
            if socialTimer <= 0 {
                say(Dialogue.tagEscaped.randomElement() ?? "Too slow!")
                endSocial(cheer: true)
                return
            }
            view.mood = .chase
            run(chaseSpeed * 0.9, dt, f)

        case .pursue:
            guard b.social == .flee else { endSocial(); return }
            facing = toward
            if socialTimer > 5.2 { view.mood = .idle; return }     // gives the other one a head start
            view.mood = .chase
            if abs(d) < 50 * scale {
                say(Dialogue.tagCaught.randomElement() ?? "Got you!")
                view.spawnHearts(2)
                b.view.spawnHearts(2)
                b.endSocial(cheer: true)
                endSocial(cheer: true)
            } else {
                advance(chaseSpeed * dt, autonomous: false, f)
            }

        case .lead:
            guard b.social == .trail, socialTimer > 0 else { endSocial(cheer: true); return }
            view.mood = .walk
            run(species.walkSpeed * 1.1, dt, f)

        case .trail:
            guard b.social == .lead else { endSocial(cheer: true); return }
            let gap = (b.cx - b.facing * 66 * scale) - cx
            if abs(gap) > 10 {
                facing = gap > 0 ? 1 : -1
                view.mood = .walk
                advance(min(abs(gap), max(species.walkSpeed, b.species.walkSpeed) * 1.6 * dt), autonomous: false, f)
            } else {
                facing = b.facing
                view.mood = .idle
            }
        }
    }

    /// Reached the other pet: now do the thing.
    func arrive(_ b: PetController) {
        meetings += 1
        mind.reunitedWithBuddy()
        switch socialKind {
        case .greet, .chat:
            view.spawnHearts(3)
            if startBanter(with: b) { break }           // the model wrote them a conversation
            say(Dialogue.buddyHello(b.species.name).randomElement() ?? "Hi!")
            if banterAsked {
                // The words are still on their way: stand together and see if they come.
                banterArrived = Date()
                facing = b.cx > cx ? 1 : -1
                b.facing = cx > b.cx ? 1 : -1
                for pet in [self, b] {
                    pet.social = .none; pet.action = .idle; pet.remaining = PetController.banterWait
                    pet.visitWait = max(pet.visitWait, PetController.banterWait + 30)
                }
            } else {
                endSocial(cheer: true)
                b.cheer(for: self, line: nil)
            }

        case .jealous:
            view.spawnHearts(2)
            say(Dialogue.jealous.randomElement() ?? "Me too!", force: true)
            endSocial(cheer: true)

        case .dance:
            say(Dialogue.danceTogether.randomElement() ?? "Dance with me!")
            apply(Decision(action: .dance, duration: 5), why: "two pets")
            b.apply(Decision(action: .dance, duration: 5), why: "two pets")

        case .nap:
            say(Dialogue.napTogether.randomElement() ?? "Nap time…")
            apply(Decision(action: .sleep, duration: 25), why: "two pets")
            if b.action != .sleep { b.apply(Decision(action: .sleep, duration: 25), why: "two pets") }

        case .showOff:
            apply(Bool.random() ? Decision(action: .power, duration: 2.2) : Decision(action: .flip, duration: 0.8), forceSay: true, why: "two pets")
            b.cheer(for: self, line: Dialogue.impressed.randomElement())

        case .tag:
            say(Dialogue.tagStart.randomElement() ?? "Tag! You're it!")
            social = .flee
            socialTimer = 5
            facing = b.cx > cx ? -1 : 1            // run the other way
            b.social = .pursue
            b.socialTimer = 6

        case .follow:
            say(Dialogue.followMe.randomElement() ?? "Follow me!")
            social = .lead
            socialTimer = 7
            facing = Bool.random() ? 1 : -1
            b.social = .trail
            b.socialTimer = 9
        }
    }

    /// The other pet did something nice next to this one.
    func cheer(for b: PetController, line: String?) {
        social = .none
        guard canAct, action != .sleep else { return }
        facing = b.cx > cx ? 1 : -1
        action = .happy
        remaining = 2.2
        view.spawnHearts(2)
        visitWait = max(visitWait, 20)
        if let line {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in self?.say(line) }
        }
    }

    /// You petted the other one. This one wants some too.
    func noticedPetting(of b: PetController) {
        guard sociable, social == .none, b.social == .none, onDock, b.onDock,
              Double.random(in: 0..<1) < 0.6 else { return }
        beginSocial(.jealous, with: b)
    }

    /// Run along the ground, turning back at the ends instead of climbing.
    func run(_ speed: CGFloat, _ dt: CGFloat, _ f: NSRect) {
        advance(speed * dt, autonomous: false, f)
        if (cx <= platform.minX + 1 && facing < 0) || (cx >= platform.maxX - 1 && facing > 0) { facing = -facing }
    }

    /// Leave a wall, the ceiling or a window top and drop to the ground.
    func comeDown() {
        guard canAct, action != .sleep, slipTimer <= 0 else { return }
        switch surface {
        case .leftWall, .rightWall, .ceiling:
            letGo()
        case .floor where platform.id != 0:
            cy -= 4                                 // just below the window top, so the fall passes it
            surface = .air
            vy = 0
        default:
            break
        }
    }

    /// Two pets standing on the same spot look like one: the companion shuffles aside.
    func stepAside(_ b: PetController) {
        guard !isMain, social == .none, b.social == .none, onDock, b.onDock, action == .idle,
              abs(b.cx - cx) < 44 * scale else { return }
        var axis: CGFloat = cx >= b.cx ? 1 : -1
        if axis > 0, cx > platform.maxX - 70 * scale { axis = -1 }
        if axis < 0, cx < platform.minX + 70 * scale { axis = 1 }
        apply(Decision(action: .walk(axis: axis), duration: 0.9), why: "making room for the other pet")
    }
}
