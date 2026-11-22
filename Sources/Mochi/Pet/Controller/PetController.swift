#if canImport(AppKit)
import AppKit
#else
import AppKitLite
#endif
#if canImport(Combine)
import Combine
#else
import AppKitLite
#endif

/// Borderless windows must be allowed to sit partly off-screen (on walls) and under the menu bar.
final class PetWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

struct Jump {
    var start: CGPoint
    var end: CGPoint
    var t: CGFloat
    var duration: CGFloat
    var height: CGFloat
    var target: Platform
}

/// Owns the pet window, runs the 30fps loop, moves the pet over the dock, screen edges and windows,
/// and reacts to music, treats, the cursor and what you are doing.
///
/// Position is tracked as the window's centre (cx, cy). The pet's feet touch its surface
/// `reach` points from the centre, which is why every surface snaps to `edge + reach`.
final class PetController {
    /// How big the pet is on screen, relative to its 120pt design size.
    var scale: CGFloat { settings.petSize.scale }
    var half: CGFloat { PetView.side / 2 * scale }
    var reach: CGFloat { 52 * scale }               // centre → surface

    let settings = PetSettings.shared
    /// The main pet owns the needs, reminders, focus sessions and toys. A companion just lives alongside it.
    let isMain: Bool
    weak var buddy: PetController?
    var species: Species { isMain ? settings.species : settings.companionSpecies }
    let mind = PetMind.shared
    let window: PetWindow
    let view = PetView(frame: NSRect(origin: .zero, size: PetView.size))
    let bubble = SpeechBubble()
    let brain: Brain
    let audio = AudioWatcher.shared
    let log = DailyLog.shared
    let calendar = CalendarWatcher()
    var cancellables = Set<AnyCancellable>()
    var timer: Timer?

    // Position & motion
    var cx: CGFloat = 300
    var cy: CGFloat = 100
    var vy: CGFloat = 0
    var surface: Surface = .floor
    var facing: CGFloat = 1
    var lastSaid = ""                       // the last thing it said, and how many things so far (Debug page, tests)
    var saidCount = 0
    var lastSpot = CGPoint.zero             // where the pet last was, and for how long it has stayed put
    var stillFor: TimeInterval = 0
    var gait: CGFloat = 0                   // 0…1: eases the pet in and out of a walk, and through turns
    var targetAngle: CGFloat = 0
    var held = false
    var vx: CGFloat = 0                     // sideways speed while thrown
    var thrown = false
    var bounces = 0
    var dragVelocity = CGPoint.zero

    // Hide and peek
    enum HidePhase { case none, going, hidden }
    var hidePhase = HidePhase.none
    var hideSide: CGFloat = -1              // which screen edge: -1 left, +1 right
    var hideShift: CGFloat = 0              // how far the window is slid past the edge

    // Two pets
    var visitWait: TimeInterval = .random(in: 12...25)     // seconds until this pet next tries to meet the other
    var meetings = 0
    var social = SocialPhase.none           // what this pet is doing with the other one right now
    var socialKind = SocialKind.greet
    var socialTimer: CGFloat = 0
    var forcedSocial: SocialKind?           // Debug page: the next get-together must be this one

    // AI: a little conversation ordered while running over to the other pet
    var banterToken = 0                     // bumped whenever a conversation is ordered, started or dropped
    var banterLines: [String]?
    var lastBanter: [String] = []           // the conversation most recently acted out
    var banterAsked = false                 // the words are still on their way
    var banterArrived: Date?                // standing together, waiting for them
    var chatReady: Date?                    // a chat's words arrived (banterLines); walk over and have it
    var lastDiaryCheck = Date.distantPast

    // Power
    var pauseReasons = Set<String>()
    var fps = 0
    var lastFrame = Date()
    var jump: Jump?
    var forceClimb = false

    // Platforms
    var platform = Platform(id: 0, minX: 0, maxX: 0, top: 0)
    var windowPlatforms: [Platform] = []
    var lastScan = Date.distantPast
    var freezeUntil = Date.distantPast      // ignore window changes while Spaces slide
    var lastFreeze = Date.distantPast
    var missingScans = 0
    var dockHidden = false                  // space is reserved for the Dock but it isn't drawn

    // Slipping off walls / ceiling
    var gripTime: TimeInterval = 0
    var slipTimer: CGFloat = 0
    var slipped = false

    // Behavior
    var action: PetAction = .idle
    var remaining: TimeInterval = 1
    var lastInteraction = Date()
    var nextGreeting = Date()
    var clickStreak = 0
    var lastClick = Date.distantPast

    // Awareness
    var media: MediaActivity = .none        // what's playing, as far as the settings let the pet care
    var onCall = false                      // a call is on (and "Stay quiet during calls" is on): keep quiet
    var playingTitle: String?               // the song or show last reacted to, so a new one is noticed
    var nextMediaMoment = Date.distantFuture   // the next little reaction to a podcast or video
    var nextActChange = Date.distantFuture     // when it switches to another act for what's playing (MediaAct)
    var privately = false                   // what's playing is in a private window: look away, remember nothing
    var userAway = false
    var activeSeconds: TimeInterval = 0
    var lastSlow = Date.distantPast
    var lastHour = -1
    var lastBattery = Date.distantPast
    var batteryWarned = false
    var wasCharging: Bool?

    // Cursor interactions
    var lastMouse = NSEvent.mouseLocation
    var lastMouseDelta = CGPoint.zero
    var shake: CGFloat = 0
    var dizzyCooldown = Date.distantPast
    var hoverTime: CGFloat = 0
    var hoverReacted = false

    // Typing along (only ever a count of key presses, never which keys)
    var keyCount = SystemInfo.keyPressCount()
    var lastKey = Date.distantPast
    var typingRate: Double = 0              // keys per second, smoothed
    var typingStreak: TimeInterval = 0      // how long you've been typing without a real pause
    var fastTyping: TimeInterval = 0
    var nextTypingCheer: TimeInterval = 60
    var fastCheerAfter = Date.distantPast

    // Gentle reminders, busy Mac, calendar
    var reminderElapsed: [ReminderKind: TimeInterval] = [:]
    var lastReminder = Date.distantPast
    var lastCPU = SystemInfo.cpuTicks()
    var lastCPUCheck = Date.distantPast
    var busySeconds: TimeInterval = 0
    var busyCooldown = Date.distantPast
    var hotCooldown = Date.distantPast
    var lastCalendarCheck = Date.distantPast
    var meetingQueue: [String] = []
    var lastMeetingSaid = Date.distantPast
    var recentMeetings: [String: Date] = [:]        // "title|minutes" → when, so the same alert is said once
    var focusPlanned = 0

    var treat: Treat?
    var ball: Ball?
    var lastKickLine = Date.distantPast
    var flipLength: TimeInterval = 0.8

    /// When the running focus session ends (nil = no session).
    var focusEnds: Date?

    let chaseSpeed: CGFloat = 170

    init(brain: Brain = LLMBrain(), isMain: Bool = true) {
        self.brain = brain
        self.isMain = isMain

        let side = PetView.side * PetSettings.shared.petSize.scale
        window = PetWindow(contentRect: NSRect(x: 0, y: 0, width: side, height: side),
                           styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        // Visible on every Space and over full-screen apps; stays put while Spaces slide.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.animationBehavior = .none
        window.hidesOnDeactivate = false
        window.contentView = view
        window.isReleasedWhenClosed = false

        // Music starting or stopping reaches the pet at once, not at its next once-a-second look around.
        NotificationCenter.default.addObserver(forName: .mochiMediaChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.timer != nil else { return }
            self.refreshMedia()
        }

        // Swiping between Spaces shuffles every window's position: pause window tracking until it settles.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.freezeUntil = Date().addingTimeInterval(1.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.window.orderFrontRegardless() }
        }

        BubbleView.scale = settings.petSize.bubbleScale
        view.species = species
        view.outfit = wornOutfit
        view.onClick = { [weak self] in self?.petted() }
        view.onDragBegan = { [weak self] in self?.dragBegan() }
        view.onDragEnded = { [weak self] in self?.dragEnded() }

        checkDock()
        let f = screenFrame
        platform = dock(f)
        cx = f.midX + (isMain ? 0 : 140)
        cy = platform.top + reach
        window.setFrameOrigin(NSPoint(x: cx - half, y: cy - half))

        (isMain ? settings.$species : settings.$companionSpecies).dropFirst().receive(on: DispatchQueue.main).sink { [weak self] s in
            guard let self else { return }
            self.view.species = s
            self.view.spawnHearts(4)
            self.say("Hi! I'm \(s.name)!", force: true)
        }.store(in: &cancellables)

        settings.$petSize.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] size in
            guard let self else { return }
            let side = PetView.side * size.scale
            BubbleView.scale = size.bubbleScale
            self.bubble.rescale()
            self.window.setContentSize(NSSize(width: side, height: side))
            if self.surface == .floor { self.cy = self.platform.top + self.reach }
            self.window.setFrameOrigin(NSPoint(x: self.cx - self.half, y: self.cy - self.half))
        }.store(in: &cancellables)

        settings.$chattiness.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.scheduleGreeting(Date())
        }.store(in: &cancellables)

        if isMain {
            settings.$outfit.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
                guard let self else { return }
                self.view.outfit = self.wornOutfit
            }.store(in: &cancellables)

            mind.onLevelUp = { [weak self] level in
                guard let self else { return }
                self.view.spawnHearts(6)
                self.say("We're \(PetMind.title(level).lowercased())s now! 💞", force: true)
                if PetAI.shared.on(.memory) { PetMemory.shared.note("Your bond grew: you are now \(PetMind.title(level).lowercased())s") }
                // A new level unlocks a new thing to wear: mention it once the first bubble has gone.
                if let gift = Outfit.allCases.first(where: { $0.unlockLevel == level }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                        self?.say(Dialogue.newOutfit(gift), force: true)
                    }
                }
            }
        }

        if isMain { PetDebug.shared.fire = { [weak self] a in self?.debug(a) } }
        scheduleGreeting(Date())
    }

    // MARK: Public controls (menu bar, right-click, settings)

    func start() {
        window.orderFrontRegardless()
        audio.start()
        lastFrame = Date()
        schedule(30)
        DispatchQueue.main.asyncAfter(deadline: .now() + (isMain ? 0.8 : 2.4)) { [weak self] in
            guard let self else { return }
            if !self.isMain {
                self.say("Hi! I'm \(self.species.name)!")
            } else if self.settings.dailyCheckIn, self.log.hasFreshYesterday, self.log.current.activeSeconds < 120,
                      let y = self.log.yesterday {
                // First visit of the day: a quick look back.
                self.say(y.summary(prefix: "Yesterday"), force: true, seconds: 7)
            } else if self.mind.isNew {
                self.say("Hi! I'm \(self.species.name)! Nice to meet you!")
            } else if self.mind.awaySeconds > 8 * 3600 {
                self.mind.reunited()
                self.view.spawnHearts(4)
                self.react("Your human just opened the app again after \(Int(self.mind.awaySeconds / 3600)) hours apart",
                           fallback: Dialogue.missedYou.randomElement() ?? "I missed you!")
            } else {
                self.say("Hi! I'm \(self.species.name)!")
            }
        }
    }

    func setContextMenu(_ menu: NSMenu) { view.menu = menu }

    /// Remove this pet from the screen for good (used when the second pet is switched off).
    func stop() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
        treat?.remove(); treat = nil
        ball?.remove(); ball = nil
        bubble.hide()
        window.orderOut(nil)
    }
}
