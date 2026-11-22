#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif

/// Developer helper: `Mochi --ai-test <server> <model> [key]` runs every AI feature once against a real
/// (or mock) OpenAI-compatible server and prints what came back. Uses a throwaway data folder, and puts
/// your own AI settings back afterwards.
enum AITest {
    static func run(_ args: [String]) {
        _ = NSApplication.shared
        let s = PetSettings.shared
        let saved = (s.aiEnabled, s.aiBaseURL, s.aiModel, s.reminderMinutes, s.outfit)
        let d = UserDefaults.standard
        let hadFlag = d.object(forKey: "aiEnabled") != nil
        func restore() {
            s.aiBaseURL = saved.1; s.aiModel = saved.2; s.reminderMinutes = saved.3; s.outfit = saved.4
            s.aiEnabled = saved.0
            if !hadFlag { d.removeObject(forKey: "aiEnabled") }
        }
        guard args.count >= 2 else { print("usage: Mochi --ai-test <server> <model> [key]"); exit(2) }
        s.aiBaseURL = args[0]; s.aiModel = args[1]; s.aiEnabled = true
        let key = args.count > 2 ? args[2] : ""

        var failures = 0
        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if !ok { failures += 1 }
            print("\(ok ? "PASS" : "FAIL")  \(name)\(detail.isEmpty ? "" : "  [\(detail)]")")
        }
        /// Keep the run loop turning until `done()` or the time is up.
        func wait(_ seconds: TimeInterval, until done: () -> Bool) {
            let end = Date().addingTimeInterval(seconds)
            while !done(), Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        }

        let ai = PetAI.shared
        let pet = PetController()
        pet.lastSlow = .distantFuture
        let sp = pet.species

        // The client itself.
        let client = LLMClient(baseURL: args[0] + "/", model: args[1], apiKey: key)
        var models: [String]?
        var finished = false
        final class Box { var models: [String]?; var done = false }
        let box = Box()
        Task.detached { let m = try? await client.models(); await MainActor.run { box.models = m; box.done = true } }
        wait(20) { box.done }
        models = box.models
        check("lists the server's models", !(models ?? []).isEmpty, (models ?? []).prefix(3).joined(separator: ", "))

        // 1. Fresh lines
        let canned = Dialogue.petted[0]
        check("first time, the canned line is used", ai.restyle(canned, species: sp) == canned)
        wait(60) { ai.generatedLineCount > 0 }
        let fresh = ai.restyle(canned, species: sp)
        check("then a written line replaces it", ai.generatedLineCount >= 4 && !Dialogue.petted.contains(fresh), "\(ai.generatedLineCount) lines, e.g. \(fresh)")
        check("exact lines are left alone", ai.restyle(Dialogue.reminder(.water)[0], species: sp) == Dialogue.reminder(.water)[0])

        // 2. Remarks
        var said = pet.saidCount
        pet.react("Music just started playing in Spotify", fallback: "FALLBACK", force: true)
        wait(18) { pet.saidCount > said }
        check("remarks on what is going on", pet.saidCount > said && pet.lastSaid != "FALLBACK", pet.lastSaid)

        // 3. Choosing what to do
        var decision: Decision?
        finished = false
        ai.decide(pet.context(pet.screenFrame), recent: ["walk", "idle"]) { decision = $0; finished = true }
        wait(60) { finished }
        check("picks its next move", decision != nil, decision.map { "\($0.action) for \(Int($0.duration))s, says \($0.line ?? "nothing")" } ?? "no decision")

        // 4. Two pets talking
        var lines: [String]?
        finished = false
        ai.banter(sp, s.companionSpecies) { lines = $0; finished = true }
        wait(60) { finished }
        check("writes two pets a conversation", (lines?.count ?? 0) >= 2, (lines ?? []).joined(separator: " / "))

        // …and the two of them acting it out when they meet.
        let chat = s.chattiness
        s.chattiness = .normal
        let other = PetController(isMain: false)
        other.lastSlow = .distantFuture
        pet.buddy = other; other.buddy = pet
        pet.cx = pet.platform.minX + 200; other.cx = pet.cx + 300
        pet.debug(.meet(.greet))
        var heard: [String] = []
        let stop = Date().addingTimeInterval(PetController.banterWait + 25)
        while Date() < stop, heard.count < 4 {
            pet.tick(1.0 / 30); other.tick(1.0 / 30)
            // Each meeting asks the model afresh, so compare against what they were actually given.
            let script = pet.lastBanter.isEmpty ? (lines ?? []) : pet.lastBanter
            for p in [pet, other] where script.contains(p.lastSaid) && heard.last != p.lastSaid {
                heard.append("\(p.species.name): \(p.lastSaid)")
                p.lastSaid = ""
            }
            RunLoop.main.run(until: Date().addingTimeInterval(1.0 / 30))
        }
        check("the two pets take turns saying it", heard.count == 4 && heard[0].hasPrefix(pet.species.name) && heard[1].hasPrefix(other.species.name),
              heard.joined(separator: " / "))

        // A longer chat about their human: written first, then they get together and act it out.
        PetMemory.shared.remember("Often works late at night")
        PetMemory.shared.remember("Drinks a lot of coffee")
        PetMemory.shared.note("Your human started a 25 minute focus session")
        var gossip: [String]?
        finished = false
        ai.banter(sp, s.companionSpecies, topic: .human, count: 6) { gossip = $0; finished = true }
        wait(90) { finished }
        check("writes a chat about their human", (gossip?.count ?? 0) >= 4, (gossip ?? []).joined(separator: " / "))

        pet.lastBanter = []
        pet.visitWait = 0
        pet.debug(.meet(.chat))
        heard = []
        let chatStop = Date().addingTimeInterval(120)
        while Date() < chatStop, heard.count < 6 {
            pet.tick(1.0 / 30); other.tick(1.0 / 30)
            for p in [pet, other] where !pet.lastBanter.isEmpty && pet.lastBanter.contains(p.lastSaid) && heard.last != p.lastSaid {
                heard.append("\(p.species.name): \(p.lastSaid)")
                p.lastSaid = ""
            }
            if !pet.lastBanter.isEmpty, heard.count == pet.lastBanter.count { break }
            RunLoop.main.run(until: Date().addingTimeInterval(1.0 / 30))
        }
        check("they get together for a chat and take turns", heard.count >= 4 && heard[0].hasPrefix(pet.species.name)
              && heard[1].hasPrefix(other.species.name), heard.joined(separator: " / "))
        pet.buddy = nil; other.stop()
        s.chattiness = chat

        // 5. Typed requests
        func ask(_ text: String, _ name: String, _ ok: @escaping () -> Bool) {
            said = pet.saidCount
            pet.ask(text)
            wait(60) { pet.saidCount >= said + 2 }           // "Hmm…" and then the answer
            check(name, ok(), "\"\(text)\" → \(pet.lastSaid)")
        }
        s.reminderMinutes = [:]
        ask("remind me to drink water every 30 minutes", "sets a reminder from a typed request") { s.interval(.water) == 30 }
        ask("start a 25 minute focus session", "starts a focus session") { pet.focusEnds != nil }
        pet.stopFocus()
        ask("remember that I love lo-fi music", "remembers a fact") { PetMemory.shared.facts.contains { $0.lowercased().contains("lo-fi") } }
        ask("how are you feeling?", "answers a question") { !pet.lastSaid.isEmpty && !pet.lastSaid.hasPrefix("Sorry") && !pet.lastSaid.hasPrefix("Hmm") }

        // 6. Diary
        var stats = DayStats(day: DailyLog.key())
        stats.activeSeconds = 4 * 3600; stats.typingSeconds = 3000; stats.focusSessions = 2; stats.focusMinutes = 50; stats.pets = 6; stats.treats = 2
        PetMemory.shared.note("Music started playing in Spotify")
        finished = false
        ai.writeDiary(stats) { _ in finished = true }
        wait(90) { finished }
        check("writes a diary entry", PetMemory.shared.hasEntry(for: stats.day), PetMemory.shared.diary.first?.text ?? "")

        // Falling back
        s.aiBaseURL = "http://127.0.0.1:9"
        said = pet.saidCount
        pet.react("anything", fallback: "FALLBACK", force: true)
        wait(8) { pet.saidCount > said }
        check("server unreachable: the canned line is said instead", pet.lastSaid == "FALLBACK", ai.lastError ?? "")

        try? FileManager.default.removeItem(at: PetAI.dataDir)
        restore()
        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
