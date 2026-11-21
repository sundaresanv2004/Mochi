import AppKit

/// Where the language model meets the pet: remarks about what is going on, typed requests,
/// and conversations with the other pet. Everything here falls back to the canned behaviour.
extension PetController {
    /// What the pet can tell the model about its surroundings.
    var surroundings: String {
        var parts = happeningNow.isEmpty ? [] : [happeningNow]
        if let b = buddy { parts.append("Your pet friend \(b.species.name) the \(b.species.rawValue) is on screen too.") }
        return parts.joined(separator: " ")
    }

    /// What is going on on the Mac right now (music, a call, a focus session), or "".
    var happeningNow: String {
        var parts: [String] = []
        switch media {
        case .music: parts.append("Music is playing\(soundSource).")
        case .video: parts.append("A video is playing\(soundSource).")
        case .call: parts.append("Your human is on a call.")
        case .other: parts.append("Some sound is playing\(soundSource).")
        case .none: break
        }
        if focusing { parts.append("A focus session is running.") }
        return parts.joined(separator: " ")
    }

    /// " in Spotify": the app with the speakers, when the audio watcher knows it.
    var soundSource: String {
        // Each source reads "bundle.id: kind"; ask the system for the app's real name.
        guard let id = audio.sources.first(where: { !$0.contains("not playing") })?.components(separatedBy: ":").first,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName,
              !app.isEmpty, app.count < 30 else { return "" }
        return " in \(app)"
    }

    /// Say something about `event`. With AI on, the model writes the line (given a few seconds);
    /// otherwise, or if it is too slow, the pet says `fallback`. `note` also jots the event down for the diary.
    func react(_ event: String, fallback: String, force: Bool = false, seconds: TimeInterval = 3.6, note: Bool = false) {
        if note, isMain, PetAI.shared.on(.memory) { PetMemory.shared.note(event) }
        guard PetAI.shared.on(.reactions), canSpeak(force: force) else {
            say(fallback, force: force, seconds: seconds)
            return
        }
        let spoken = saidCount
        DebugLog.add(.ai, "Asked the model for a remark: \(event)", pet: species.name)
        PetAI.shared.reaction(to: event, species: species, extra: surroundings) { [weak self] line in
            guard let self else { return }
            // Something else was said while the model was thinking: don't talk over it.
            if !force, self.saidCount != spoken, self.bubble.visible {
                DebugLog.add(.ai, "Remark dropped: something else was said meanwhile", pet: self.species.name)
                return
            }
            self.say(line ?? fallback, force: force, seconds: line == nil ? seconds : max(seconds, 4.5))
        }
    }

    // MARK: Typed requests

    /// Something the human typed in the Ask box.
    func ask(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        touch()
        guard PetAI.shared.on(.commands) else {
            say("I can't understand typing yet. Switch on AI in Settings!", force: true, seconds: 5)
            return
        }
        if action == .sleep, canAct { action = .idle; remaining = 2 }
        say("Hmm… 🤔", force: true, seconds: 30)
        let wearable = Outfit.unlocked(at: mind.level).map { $0.label.lowercased() }.joined(separator: ", ")
        let extra = surroundings + " You can wear: \(wearable). You are wearing: \(wornOutfit.label.lowercased())."
        PetAI.shared.command(text, species: species, extra: extra) { [weak self] cmd in
            guard let self else { return }
            guard let cmd else {
                self.say("Sorry, my brain didn't answer. Check the AI settings?", force: true, seconds: 5)
                return
            }
            if PetAI.shared.on(.memory) { PetMemory.shared.note("Your human asked: \"\(text.prefix(80))\"") }
            DebugLog.add(.ai, "Request understood as: \(cmd.action)", pet: self.species.name,
                         detail: "You typed: \(text)\nminutes: \(cmd.minutes.map(String.init) ?? "-")  value: \(cmd.value ?? "-")\nsay: \(cmd.say ?? "-")")
            let before = self.saidCount
            let problem = self.perform(cmd)
            // The action may have said something of its own (a treat, a focus session); the reply goes on top.
            if let line = problem ?? cmd.say {
                self.say(line, force: true, seconds: 6)
            } else if self.saidCount == before {
                self.say("Okay!", force: true)
            }
        }
    }

    /// Carries out one command. Returns a spoken explanation if it could not be done.
    func perform(_ c: PetCommand) -> String? {
        let value = (c.value ?? "").lowercased()
        func act(_ a: PetAction, _ seconds: TimeInterval) -> String? {
            guard canAct else { return "I'm a bit busy in mid-air!" }
            apply(Decision(action: a, duration: seconds), forceSay: true, why: "your request")
            return nil
        }
        /// The nearest interval the settings offer.
        func snap(_ minutes: Int) -> Int {
            ReminderKind.intervals.min { abs($0 - minutes) < abs($1 - minutes) } ?? minutes
        }

        switch c.action {
        case "none", "talk", "":
            return nil
        case "treat": giveTreat()
        case "ball": playBall()
        case "come": comeHere()
        case "sleep": sleepNow()
        case "wake": if action == .sleep { return act(.happy, 1.6) }
        case "dance": return act(.dance, 6)
        case "spin": return act(.spin, 0.9)
        case "flip": return act(.flip, 0.8)
        case "zoomies": return act(.zoomies, 4)
        case "stretch": return act(.stretch, 2.4)
        case "power": powerMove()
        case "trick": trick()
        case "hide":
            guard context(screenFrame).canHide else { return "I need to be down on the Dock to hide." }
            return act(.hide, 15)
        case "climb":
            guard context(screenFrame).canClimb else { return "I can only start climbing from the Dock." }
            return act(.climbEdge, 12)
        case "go_left", "go_right":
            guard canAct else { return "I'm a bit busy in mid-air!" }
            if surface != .floor { comeDown() }
            return act(.walk(axis: c.action == "go_left" ? -1 : 1), 14)
        case "come_down": comeDown()
        case "bring_back": bringBack()
        case "visit":
            guard buddy != nil else { return "There's no other pet to visit. Turn one on in Settings!" }
            forcedSocial = .greet; social = .none; visitWait = 0
        case "check_in": checkIn()
        case "focus": startFocus(minutes: min(180, max(5, c.minutes ?? 25)))
        case "stop_focus": stopFocus()
        case "reminder":
            guard let kind = ReminderKind.allCases.first(where: { value.contains($0.rawValue) || $0.label.lowercased().contains(value) }),
                  !value.isEmpty else { return "I can remind you about water, posture or resting your eyes." }
            let m = c.minutes ?? kind.defaultMinutes
            settings.reminderMinutes[kind.rawValue] = m > 0 ? snap(m) : 0
            reminderElapsed[kind] = 0
        case "stretch_reminder":
            let m = c.minutes ?? 50
            settings.breakReminders = m > 0
            if m > 0 { settings.breakMinutes = snap(m) }
            activeSeconds = 0
        case "outfit":
            let off = ["none", "nothing", "off", ""].contains(value)
            guard let o = off ? Outfit.none : Outfit.allCases.first(where: {
                $0 != .none && (value.contains($0.label.lowercased()) || $0.label.lowercased().contains(value) || value.contains($0.rawValue.lowercased()))
            }) else { return "I don't have anything like that to wear." }
            guard o.unlockLevel <= mind.level else { return "I can't wear the \(o.label.lowercased()) yet. We need to be closer friends first!" }
            settings.outfit = o
            view.spawnHearts(2)
        case "size":
            guard let s = PetSize.allCases.first(where: { value.contains($0.rawValue) }) else { return "Small, medium or large?" }
            settings.petSize = s
        case "speech":
            let wanted = value == "silent" ? "off" : value
            guard let ch = Chattiness.allCases.first(where: { wanted.contains($0.rawValue) }) else { return "Silent, quiet, normal or chatty?" }
            settings.chattiness = ch
        case "second_pet":
            settings.secondPet = !["off", "false", "no", "0"].contains(value)
        case "remember":
            guard let fact = c.value, PetAI.shared.on(.memory) else { return "My memory is switched off in Settings." }
            if !PetMemory.shared.remember(fact) { return "I already know that!" }
        case "forget":
            guard !value.isEmpty, PetMemory.shared.forget(matching: value) > 0 else { return "I don't remember anything about that." }
        default:
            return nil                      // an action it made up: just say the reply
        }
        return nil
    }

    // MARK: Two pets talking

    /// Order a little conversation while this pet runs over to the other one.
    func prepareBanter(with b: PetController) {
        banterToken += 1
        banterLines = nil
        banterArrived = nil
        chatReady = nil
        banterAsked = PetAI.shared.on(.banter)
        guard banterAsked else { return }
        DebugLog.add(.social, "Ordered a hello conversation with \(b.species.name) from the model", pet: species.name)
        let token = banterToken
        PetAI.shared.banter(species, b.species, topic: .hello, now: happeningNow) { [weak self, weak b] lines in
            guard let self, let b, self.banterToken == token else { return }
            self.banterAsked = false
            guard let lines else {
                // No conversation is coming: if they are standing there waiting, let them get on with things.
                DebugLog.add(.social, "No hello conversation came back", pet: self.species.name)
                if self.banterArrived != nil {
                    self.banterArrived = nil
                    for pet in [self, b] where pet.action == .idle { pet.remaining = min(pet.remaining, 1) }
                }
                return
            }
            self.banterLines = lines
            // Already standing together, waiting for the words? Start talking.
            if let at = self.banterArrived, Date().timeIntervalSince(at) < Self.banterWait { self.startBanter(with: b) }
        }
    }

    /// Order a longer conversation for a chat. The pets carry on as usual meanwhile; once the words are
    /// written, the next get-together is that chat. A slow model then never leaves them standing around.
    func orderChat(with b: PetController) {
        banterToken += 1
        banterLines = nil
        banterArrived = nil
        chatReady = nil
        banterAsked = true
        let token = banterToken
        let now = happeningNow
        let topic = PetAI.shared.pickBanterTopic(now: now)
        DebugLog.add(.social, "Ordered a chat about \(topic.rawValue) with \(b.species.name); they meet once it's written", pet: species.name)
        PetAI.shared.banter(species, b.species, topic: topic, now: now, count: 6) { [weak self] lines in
            guard let self, self.banterToken == token else { return }
            self.banterAsked = false
            guard let lines else {
                DebugLog.add(.social, "The chat never came back; carrying on as usual", pet: self.species.name)
                return
            }
            DebugLog.add(.social, "Chat is ready (\(lines.count) lines)", pet: self.species.name)
            self.banterLines = lines
            self.chatReady = Date()
            self.visitWait = min(self.visitWait, 1)
        }
    }

    /// A chat written more than two minutes ago is about a moment that has passed.
    var chatIsStale: Bool { chatReady.map { Date().timeIntervalSince($0) > 120 } ?? false }

    /// How long two pets that just met stand together waiting for the model's conversation.
    /// Generous, so a slow local model still gets its lines in.
    static let banterWait: TimeInterval = 20

    /// The two pets take turns with the lines, facing each other. Returns false if there is nothing to say.
    @discardableResult
    func startBanter(with b: PetController) -> Bool {
        guard let lines = banterLines, !lines.isEmpty, canAct, b.canAct else { return false }
        banterLines = nil
        banterArrived = nil
        chatReady = nil
        lastBanter = lines
        DebugLog.add(.social, "Talking with \(b.species.name)", pet: species.name,
                     detail: lines.enumerated().map { "\($0.offset % 2 == 0 ? species.name : b.species.name): \($0.element)" }.joined(separator: "\n"))
        banterToken += 1
        let token = banterToken
        // Longer lines stay up longer, so there is time to read them.
        let shown = lines.map { min(5.5, max(2.7, 1.4 + Double($0.count) * 0.05)) }
        let starts = shown.indices.map { i in shown[..<i].reduce(0, +) }
        let total = shown.reduce(0, +) + 0.4
        for pet in [self, b] {
            pet.action = .idle
            pet.remaining = total
            pet.social = .none
            pet.visitWait = max(pet.visitWait, total + 30)
        }
        facing = b.cx > cx ? 1 : -1
        b.facing = cx > b.cx ? 1 : -1
        for (i, line) in lines.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + starts[i]) { [weak self, weak b] in
                guard let self, let b, self.banterToken == token, self.buddy === b else { return }
                let speaker = i % 2 == 0 ? self : b
                let listener = i % 2 == 0 ? b : self
                // Either one wandered off, fell asleep or got picked up: the chat is over.
                guard speaker.canAct, listener.canAct, speaker.action != .sleep, listener.action != .sleep,
                      abs(speaker.cx - listener.cx) < 160 * self.scale else {
                    DebugLog.add(.social, "Conversation cut short after \(i) of \(lines.count) lines", pet: self.species.name)
                    self.banterToken += 1
                    return
                }
                listener.bubble.hide()
                speaker.say(line, seconds: shown[i] - 0.2)
                speaker.action = .happy
                speaker.remaining = max(speaker.remaining, 1.2)
                if i == lines.count - 1 { speaker.view.spawnHearts(2); listener.view.spawnHearts(2) }
            }
        }
        return true
    }
}
