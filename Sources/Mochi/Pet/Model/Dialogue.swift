import Foundation

/// Everything the pet can say on its own. With AI on, a model rewrites most of these (see `moments`).
enum Dialogue {
    static func timeGreeting(hour: Int) -> String {
        switch hour {
        case 5..<12: return "Good morning! ☀️"
        case 12..<17: return "Good afternoon! 🌤"
        case 17..<22: return "Good evening! 🌆"
        default: return "Still up? 🌙"
        }
    }

    static let general = [
        "Hi!", "Hello there!", "Hey, you! 👋", "Oh, hi!", "Miss me?",
        "You're doing great! ✨", "Drink some water 💧", "Stretch your legs a bit!",
        "Rest your eyes for a sec 👀", "Need a break? ☕️"
    ]

    /// Lines that only a pet who knows you well would say.
    static func bonded(level: Int, days: Int) -> [String] {
        var l = ["I like hanging out with you 💕", "You're my favourite human!"]
        if days > 1 { l.append("\(days) days together! 🎉") }
        if level >= 5 { l += ["Best friends forever! 💖", "I'd climb any screen edge for you."] }
        return l
    }

    static func greeting(species: Species, hour: Int, bondLevel: Int = 1, days: Int = 1) -> String {
        if bondLevel >= 3, Int.random(in: 0..<5) == 0 {
            return bonded(level: bondLevel, days: days).randomElement() ?? "Hi!"
        }
        let r = Int.random(in: 0..<10)
        if r < 3 { return timeGreeting(hour: hour) }
        if r < 7 { return species.lines.randomElement() ?? "Hi!" }
        return general.randomElement() ?? "Hi!"
    }

    static let petted = ["Hehe!", "That tickles!", "Again, again!", "More pets please 💕", "Love it!"]
    static let startled = ["Zzz… huh?!", "Wha—? I was sleeping!", "Five more minutes…"]
    static let dragged = ["Wheee!", "Put me down! …or don't.", "Whoa whoa whoa!", "I believe I can fly!"]
    static let landedWindow = ["Nice view up here!", "King of this window 👑", "Found a cozy spot!"]
    static let clung = ["Got a grip!", "Spider-pet! 🕷", "Look, I'm climbing!"]
    static let slipping = ["Uh oh…", "My grip!", "Hold on—", "I'm slipping!"]
    static let ouch = ["Ow! I'm okay.", "Ta-da! …on purpose.", "That was my plan all along.", "Nailed the landing!"]
    static let leaping = ["Hup!", "Boing!", "Up we go!"]
    static let yum = ["Yum! 😋", "Nom nom nom!", "Delicious!", "Thank you! 💖"]
    static let hover = ["Oh, hello there!", "You're so close!", "Boop?", "Hi hi hi!"]
    static let treatDropped = ["Ooh, a treat!", "Food?!", "Is that for me?!"]

    // Needs
    static func hungry(_ s: Species) -> [String] {
        ["I'm hungry… \(s.treatEmoji)?", "My tummy is rumbling…", "Snack time? \(s.treatEmoji)", "I could really go for a \(s.treatEmoji)"]
    }
    static let lonely = ["Play with me? 🥺", "Pet me? Just once?", "I'm a little lonely…", "Hey… remember me?"]
    static let sleepy = ["So sleepy… 😴", "Need… a nap…", "Can't keep my eyes open…"]
    static let stuffed = ["I'm stuffed! Maybe later 😌", "No more, I'll pop!", "So full…"]
    static let missedYou = ["I missed you! 💕", "You're back! I waited for you!", "There you are! 🥹"]

    // Playing ball
    static let ballDropped = ["Ooh, let's play!", "Ball!!", "Mine mine mine!"]
    static let kick = ["Boing!", "Hah!", "Got it!", "Take that!", "Whee!"]
    static let playedEnough = ["That was fun! 💖", "Again sometime?", "Phew, good game!"]
    static let tooTired = ["Too tired to play… 😴", "Later? I need a nap first."]

    // Typing along
    static let typingRoll = ["You're on a roll! ✨", "Look at you go!", "Tap tap tap… I like the rhythm 🎶"]
    static let typingLong = ["So productive today! 💪", "Still going! You're unstoppable.", "That's a lot of typing. Proud of you 💖"]
    static let typingFast = ["Whoa, fast fingers! ⌨️", "Speedy!! 💨", "Are your keys okay?! 🔥"]

    // Power moves
    static func power(_ s: Species) -> [String] {
        switch s {
        case .dragon: return ["FWOOOSH! 🔥", "Dragon breath!", "Too hot to handle!"]
        case .robot: return ["Overcharge! ⚡️", "Weapons hot.", "Maximum power!"]
        case .dino: return ["RAAAWR!! 🦖", "Fear my mighty roar!", "ROOOAR!"]
        case .wolf: return ["AWOOOO!! 🐺", "Hear me howl!", "The hunt is on!"]
        case .shark: return ["CHOMP!! 🦈", "Feeding frenzy!", "Jaws out!"]
        case .ghost: return ["BOO!! 👻", "Spooky power!"]
        default: return ["Ta-daa! ✨", "Special move!", "Power up! ⭐️"]
        }
    }

    // Ball rally
    static func rally(_ kicks: Int, record: Bool) -> String {
        if record { return "\(kicks) kicks! New record! 🏆" }
        return kicks <= 2 ? "Aw, missed! \(kicks) kick\(kicks == 1 ? "" : "s")." : "\(kicks) kicks! Good rally 💪"
    }

    // Being thrown
    static let thrown = ["Wheeeee!", "I can flyyy!", "Yeet!!", "Not agaaain!"]
    static let crashLanded = ["Again! Again! 😵‍💫", "The room is spinning…", "Ten out of ten landing.", "Whoa… do that again!"]

    // Hide and peek
    static let peekaboo = ["Peekaboo! 👀", "Boo! Found you!", "You can't see me… oh.", "Hehe, I was hiding!"]

    // Two pets
    static func buddyHello(_ name: String) -> [String] {
        ["Hi \(name)!", "Tag, you're it!", "\(name)! Play with me!", "Boop!", "Best buddies! 💕"]
    }

    static func calling(_ name: String) -> [String] { ["Hey \(name)!", "\(name)! Wait there!", "Coming over!"] }
    static func comeDown(_ name: String) -> [String] { ["\(name), come down!", "Hey \(name), get down here!", "Come play, \(name)!"] }
    static let tagStart = ["Tag! You're it!", "Can't catch me!", "Catch me if you can!"]
    static let tagCaught = ["Got you!", "Tagged!", "Hah, caught you!"]
    static let tagEscaped = ["Too slow!", "Never caught me!", "I win!"]
    static let followMe = ["Follow me!", "This way!", "Come on, keep up!"]
    static let danceTogether = ["Dance with me!", "Let's dance! 🎶", "Shake it!"]
    static let napTogether = ["Nap buddies… 💤", "Room for one more?", "Shh… sleepy time."]
    static let impressed = ["Whoa!", "So cool!", "Do it again!", "Show-off… 😏"]
    static let newScreen = ["Ooh, another screen!", "What's over here?", "Exploring!", "More room to roam!"]
    static let jealous = ["Me too! Me too!", "Hey, what about me?", "My turn!"]

    // Outfits
    static func newOutfit(_ o: Outfit) -> String { "Ooh, I can wear a \(o.label.lowercased()) now! ✨" }

    // Gentle reminders
    static func reminder(_ kind: ReminderKind) -> [String] {
        switch kind {
        case .water: return ["Time for a sip of water 💧", "Water break! 💧", "Stay hydrated, okay? 💧"]
        case .posture: return ["Shoulders down, back straight 🧍", "How's your posture? 🧍", "Sit up tall with me!"]
        case .eyes: return ["Look at something far away for 20 seconds 👀", "Rest your eyes a moment 👀", "Blink! And look out the window 🌳"]
        }
    }

    // Busy Mac
    static let busyMac = ["Phew, your Mac is working hard! 🥵", "So… much… computing…", "Is something heavy running? 💦"]
    static let hotMac = ["It's getting warm in here 🔥", "Your Mac is running hot. Give it a moment? 🌡"]

    // Calendar
    static func meeting(_ title: String, minutes: Int) -> String {
        minutes == 0 ? "📅 \(title) is starting now!" : "📅 \(title) in \(inTime(minutes))!"
    }

    /// "5 min", "1 hr", "1 hr 30 min", "2 days".
    static func inTime(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        if minutes < 24 * 60 {
            let h = minutes / 60, m = minutes % 60
            return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
        }
        let days = Int((Double(minutes) / (24 * 60)).rounded())
        return days == 1 ? "1 day" : "\(days) days"
    }

    // Focus sessions
    static let focusStart = ["Focus time! I'll keep quiet 🤫", "You've got this! I'll be right here.", "Let's do this! 💪"]
    static let focusDone = ["Focus done! Great work 🎉 Time for a break.", "You did it! 🎉 Stretch a little?", "All done! Proud of you 💖"]
    static let focusStopped = ["Okay, break time!", "Stopping here. Nice effort!"]

    // MARK: For the AI

    /// A group of canned lines and the moment they are for. With AI switched on, the model writes fresh
    /// lines for each moment in the pet's own voice; these stay as the examples and the fallback.
    /// Reminders, calendar alerts and anything with a number in it are left out: those must stay exact.
    struct Moment {
        let key: String
        let about: String
        let lines: [String]
    }

    static func moments(for s: Species) -> [Moment] {
        [
            Moment(key: "hello", about: "saying hi to your human out of the blue, or a tiny kind nudge", lines: general),
            Moment(key: "self", about: "a little in-character remark about yourself or what you feel like doing", lines: s.lines),
            Moment(key: "bonded", about: "telling your human how much you like them", lines: ["I like hanging out with you 💕", "You're my favourite human!"]),
            Moment(key: "petted", about: "your human just petted you", lines: petted),
            Moment(key: "startled", about: "you were woken up by a poke while asleep", lines: startled),
            Moment(key: "dragged", about: "your human picked you up and is carrying you around", lines: dragged),
            Moment(key: "landedWindow", about: "you just jumped up onto the top of a window", lines: landedWindow),
            Moment(key: "clung", about: "you just grabbed the edge of the screen and started climbing", lines: clung),
            Moment(key: "slipping", about: "you are losing your grip on the wall and about to fall", lines: slipping),
            Moment(key: "ouch", about: "you just fell and landed on the ground, playing it cool", lines: ouch),
            Moment(key: "leaping", about: "the instant you jump (two words at most)", lines: leaping),
            Moment(key: "yum", about: "you just ate a treat", lines: yum),
            Moment(key: "hover", about: "the mouse cursor is hovering right over you", lines: hover),
            Moment(key: "treatDropped", about: "a treat just dropped from the sky for you", lines: treatDropped),
            Moment(key: "hungry", about: "you are hungry and hinting for a snack (your favourite is \(s.treatEmoji))", lines: hungry(s)),
            Moment(key: "lonely", about: "you are lonely and want attention", lines: lonely),
            Moment(key: "sleepy", about: "you can barely stay awake", lines: sleepy),
            Moment(key: "stuffed", about: "you are offered a treat but are far too full", lines: stuffed),
            Moment(key: "missedYou", about: "your human is back after many hours away", lines: missedYou),
            Moment(key: "ballDropped", about: "a toy just appeared to play with", lines: ballDropped),
            Moment(key: "kick", about: "the instant you kick the ball (two words at most)", lines: kick),
            Moment(key: "playedEnough", about: "the ball game just ended", lines: playedEnough),
            Moment(key: "tooTired", about: "you are too tired to play right now", lines: tooTired),
            Moment(key: "typingRoll", about: "your human has been typing steadily for a minute", lines: typingRoll),
            Moment(key: "typingLong", about: "your human has been typing for a very long time", lines: typingLong),
            Moment(key: "typingFast", about: "your human is typing extremely fast", lines: typingFast),
            Moment(key: "power", about: "shouting as you unleash your signature power move", lines: power(s)),
            Moment(key: "thrown", about: "you were just thrown through the air", lines: thrown),
            Moment(key: "crashLanded", about: "you crash-landed after being thrown and are dizzy", lines: crashLanded),
            Moment(key: "peekaboo", about: "you pop out from hiding behind the screen edge", lines: peekaboo),
            Moment(key: "tagStart", about: "starting a game of tag with your pet friend", lines: tagStart),
            Moment(key: "tagCaught", about: "you just caught your pet friend in tag", lines: tagCaught),
            Moment(key: "tagEscaped", about: "your pet friend failed to catch you in tag", lines: tagEscaped),
            Moment(key: "followMe", about: "telling your pet friend to follow you", lines: followMe),
            Moment(key: "danceTogether", about: "inviting your pet friend to dance", lines: danceTogether),
            Moment(key: "napTogether", about: "settling down for a nap next to your pet friend", lines: napTogether),
            Moment(key: "impressed", about: "your pet friend just did an impressive trick", lines: impressed),
            Moment(key: "newScreen", about: "you just crossed onto another display", lines: newScreen),
            Moment(key: "jealous", about: "your human petted the other pet and you want some too", lines: jealous),
            Moment(key: "busyMac", about: "the Mac's processor has been flat out for a while", lines: busyMac),
            Moment(key: "hotMac", about: "the Mac is running hot", lines: hotMac),
            Moment(key: "focusStart", about: "a focus session starts: you promise to keep quiet and cheer them on", lines: focusStart),
            Moment(key: "focusDone", about: "a focus session just finished: celebrate and suggest a break", lines: focusDone),
            Moment(key: "focusStopped", about: "your human stopped a focus session early", lines: focusStopped)
        ] + mediaMoments
    }
}
