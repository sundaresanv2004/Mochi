import Foundation

/// Plain-text helpers for spoken requests, shared by the Mac and Windows recognisers: spotting the
/// wake phrase ("Hey Mochi") in a transcript, and understanding a few requests without a language model.
enum WakePhrase {
    /// Words that can start the wake phrase. Recognisers often drop or mishear the first word, so the
    /// name on its own at the very start also counts ("Mochi, dance").
    static let greetings: Set<String> = ["hey", "hi", "hello", "ok", "okay", "yo", "hay", "a"]

    /// What the recogniser heard, split into words: lower case, no punctuation.
    static func words(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
    }

    /// Whether `word` sounds like `name`: the same, or one letter off for names of four letters or more
    /// ("mochie", "mocha" for Mochi). A name of two words ("Captain Paws") is matched by its first word.
    static func soundsLike(_ word: String, _ name: String) -> Bool {
        let n = words(name).first ?? name.lowercased()
        if word == n { return true }
        guard n.count >= 4, abs(word.count - n.count) <= 1, word.first == n.first else { return false }
        return distance(word, n) <= 1
    }

    /// If `text` starts with the wake phrase for `name`, the words after it ("" when there are none);
    /// otherwise nil. The phrase may sit a word or two into the transcript ("um hey mochi dance").
    static func command(in text: String, name: String) -> String? {
        let w = words(text)
        let nameWords = max(1, words(name).count)
        for i in w.indices.prefix(4) where soundsLike(w[i], name) {
            // On its own, the name must open the transcript (or follow a greeting): "I love mochi" is not a call.
            guard i == 0 || greetings.contains(w[i - 1]) else { continue }
            // Skip the rest of a two-word name, if the recogniser heard it.
            let after = min(w.count, i + nameWords)
            return w[after...].joined(separator: " ")
        }
        return nil
    }

    /// Levenshtein distance; names are short, so the simple table is fine.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var prev = row[0]
            row[0] = i
            for j in 1...b.count {
                let cur = row[j]
                row[j] = a[i - 1] == b[j - 1] ? prev : min(prev, row[j], row[j - 1]) + 1
                prev = cur
            }
        }
        return row[b.count]
    }
}

/// A handful of requests the pet understands without a language model, so talking to it works with AI
/// switched off. With AI on, everything goes to the model instead (it understands far more).
enum LocalCommands {
    /// The command for `text` and what the pet says back, or nil when it is not one it knows.
    static func match(_ text: String) -> PetCommand? {
        let w = WakePhrase.words(text)
        guard !w.isEmpty else { return nil }
        let joined = " " + w.joined(separator: " ") + " "
        func has(_ phrases: String...) -> Bool { phrases.contains { joined.contains(" \($0) ") } }
        func cmd(_ action: String, _ say: String, minutes: Int? = nil, value: String? = nil) -> PetCommand {
            PetCommand(action: action, minutes: minutes, value: value, say: say)
        }
        let n = number(in: w)

        // Longer phrases first: "stop focus" before "focus", "come down" before "come".
        if has("stop focus", "end focus", "cancel focus", "stop the focus", "end the focus") { return cmd("stop_focus", "Focus session over. Nice work! 🎉") }
        if has("focus", "pomodoro") { return cmd("focus", "Let's focus! I'll keep quiet. 🤫", minutes: n ?? 25) }
        if has("remind", "reminder"), let kind = ["water": "water", "drink": "water", "posture": "posture", "sit up": "posture",
                                                   "eyes": "eyes", "eye": "eyes"].first(where: { has($0.key) })?.value {
            return cmd("reminder", "Okay, I'll remind you! ⏰", minutes: n, value: kind)
        }
        if has("wake up") { return cmd("wake", "I'm awake! ☀️") }
        if has("sleep", "nap", "bed", "bedtime", "good night", "goodnight") { return cmd("sleep", "Nap time… 💤") }
        if has("come down", "get down", "jump down") { return cmd("come_down", "Coming down!") }
        if has("come here", "come back", "come to me", "over here", "come") { return cmd("come", "Coming! 🐾") }
        if has("treat", "treats", "snack", "food", "hungry", "eat", "cookie") { return cmd("treat", "Yum, thank you! 😋") }
        if has("ball", "fetch", "play") { return cmd("ball", "Throw it, throw it! ⚽") }
        if has("dance", "dancing", "boogie") { return cmd("dance", "Watch my moves! 💃") }
        if has("backflip", "flip", "somersault") { return cmd("flip", "Hup! 🤸") }
        if has("spin", "twirl", "turn around") { return cmd("spin", "Wheee! 🌀") }
        if has("zoomies", "zoom", "run around") { return cmd("zoomies", "Zoom zoom! 💨") }
        if has("stretch") { return cmd("stretch", "Mmm, good stretch.") }
        if has("power move", "power", "super") { return cmd("power", "Stand back! ⚡") }
        if has("trick", "tricks") { return cmd("trick", "Ta-da! ✨") }
        if has("hide") { return cmd("hide", "You can't see me! 🙈") }
        if has("climb") { return cmd("climb", "Up I go! 🧗") }
        if has("go left", "left") { return cmd("go_left", "This way!") }
        if has("go right", "right") { return cmd("go_right", "That way!") }
        if has("check in", "checkin", "how was my day", "my day", "stats") { return cmd("check_in", "Let's see how today's going…") }
        if has("how are you", "how you doing", "how's it going") { return cmd("talk", "I'm great now that you're talking to me! 💕") }
        if has("hello", "hi", "hey", "good morning", "good afternoon", "good evening") { return cmd("talk", "Hi there! 👋") }
        if has("thank you", "thanks", "good job", "good boy", "good girl", "love you", "good pet") { return cmd("talk", "Aww! 💕") }
        return nil
    }

    /// The first number in what was said: digits ("25") or simple words ("twenty five").
    static func number(in w: [String]) -> Int? {
        let ones = ["zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
                    "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16,
                    "seventeen": 17, "eighteen": 18, "nineteen": 19, "an": 1, "a": 1]
        let tens = ["twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90]
        for (i, word) in w.enumerated() {
            if let d = Int(word.filter(\.isNumber)), word.first?.isNumber == true {
                return i + 1 < w.count && w[i + 1].hasPrefix("hour") ? 60 * d : d
            }
            if word == "hour" || word == "hours" { return 60 * (i > 0 ? (ones[w[i - 1]] ?? 1) : 1) }
            if let t = tens[word] {
                if i + 1 < w.count, let o = ones[w[i + 1]], o < 10, o > 0 { return t + o }
                return t
            }
            // "a"/"an" only count right before "hour" (handled above).
            if word != "a", word != "an", let o = ones[word] {
                if i + 1 < w.count, w[i + 1].hasPrefix("hour") { return 60 * o }
                return o
            }
        }
        return nil
    }
}
