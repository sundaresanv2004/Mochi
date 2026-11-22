import Foundation
#if canImport(Combine)
import Combine
#else
import AppKitLite
#endif

enum Chattiness: String, CaseIterable, Identifiable {
    case off, quiet, normal, chatty

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Silent"
        case .quiet: return "Quiet"
        case .normal: return "Normal"
        case .chatty: return "Chatty"
        }
    }

    /// Seconds between random "hi"s (nil = never).
    var interval: ClosedRange<TimeInterval>? {
        switch self {
        case .off: return nil
        case .quiet: return 150...300
        case .normal: return 40...100
        case .chatty: return 12...35
        }
    }
}

enum PetSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    /// Speech bubbles shrink with the pet, but less steeply so the text stays readable (10 / 11 / 13pt).
    var bubbleScale: CGFloat {
        switch self {
        case .small: return 0.77
        case .medium: return 0.85
        case .large: return 1
        }
    }

    /// Relative to the 120pt design size.
    var scale: CGFloat {
        switch self {
        case .small: return 0.55
        case .medium: return 0.72
        case .large: return 1
        }
    }
}

/// The gentle nudges the pet can give while you work.
enum ReminderKind: String, CaseIterable, Identifiable {
    case water, posture, eyes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .water: return "Drink water"
        case .posture: return "Check my posture"
        case .eyes: return "Rest my eyes"
        }
    }

    var symbol: String {
        switch self {
        case .water: return "drop"
        case .posture: return "figure.stand"
        case .eyes: return "eye"
        }
    }

    var defaultMinutes: Int {
        switch self {
        case .water: return 60
        case .posture: return 45
        case .eyes: return 20
        }
    }

    static let intervals = [10, 15, 20, 30, 45, 50, 60, 90, 120]
}

/// User preferences, saved automatically to UserDefaults.
final class PetSettings: ObservableObject {
    static let shared = PetSettings()
    private let d = UserDefaults.standard

    @Published var species: Species { didSet { d.set(species.rawValue, forKey: "species") } }
    @Published var petSize: PetSize { didSet { d.set(petSize.rawValue, forKey: "petSize") } }
    @Published var chattiness: Chattiness { didSet { d.set(chattiness.rawValue, forKey: "chattiness") } }
    @Published var walkOnWindows: Bool { didSet { d.set(walkOnWindows, forKey: "walkOnWindows") } }
    @Published var climbEdges: Bool { didSet { d.set(climbEdges, forKey: "climbEdges") } }
    @Published var followCursor: Bool { didSet { d.set(followCursor, forKey: "followCursor") } }
    @Published var reactToMedia: Bool { didSet { d.set(reactToMedia, forKey: "reactToMedia") } }
    @Published var reactToTyping: Bool { didSet { d.set(reactToTyping, forKey: "reactToTyping") } }
    @Published var secondPet: Bool { didSet { d.set(secondPet, forKey: "secondPet") } }
    @Published var companionSpecies: Species { didSet { d.set(companionSpecies.rawValue, forKey: "companionSpecies") } }
    @Published var outfit: Outfit { didSet { d.set(outfit.rawValue, forKey: "outfit") } }
    @Published var dailyCheckIn: Bool { didSet { d.set(dailyCheckIn, forKey: "dailyCheckIn") } }
    @Published var calendarAlerts: Bool { didSet { d.set(calendarAlerts, forKey: "calendarAlerts") } }
    // Google Calendar (the sign-in itself lives in `GoogleCalendar` and the keychain)
    @Published var googleCalendarAlerts: Bool { didSet { d.set(googleCalendarAlerts, forKey: "googleCalendarAlerts") } }
    @Published var googleAlertAtStart: Bool { didSet { d.set(googleAlertAtStart, forKey: "googleAlertAtStart") } }
    /// Your own OAuth client, when the build doesn't ship one. Its secret is kept in the keychain.
    @Published var googleClientID: String { didSet { d.set(googleClientID, forKey: "googleClientID") } }
    /// Minutes between each gentle reminder; 0 = off.
    @Published var reminderMinutes: [String: Int] { didSet { d.set(reminderMinutes, forKey: "reminderMinutes") } }
    @Published var breakReminders: Bool { didSet { d.set(breakReminders, forKey: "breakReminders") } }
    /// Minutes of work before the stretch reminder.
    @Published var breakMinutes: Int { didSet { d.set(breakMinutes, forKey: "breakMinutes") } }
    /// React to sound from browsers, games and other apps that aren't known music or video players.
    /// Stay quiet while a chat app is using the microphone.
    @Published var quietOnCalls: Bool { didSet { d.set(quietOnCalls, forKey: "quietOnCalls") } }
    @Published var reactToOtherAudio: Bool { didSet { d.set(reactToOtherAudio, forKey: "reactToOtherAudio") } }
    @Published var systemAware: Bool { didSet { d.set(systemAware, forKey: "systemAware") } }
    // AI (any OpenAI-compatible server). Off until a server and model are set.
    @Published var aiEnabled: Bool { didSet { d.set(aiEnabled, forKey: "aiEnabled") } }
    @Published var aiBaseURL: String { didSet { d.set(aiBaseURL, forKey: "aiBaseURL") } }
    @Published var aiModel: String { didSet { d.set(aiModel, forKey: "aiModel") } }
    /// Kept in the keychain rather than the preferences file.
    @Published var aiKey: String { didSet { if aiKey != oldValue { Keychain.write(aiKey) } } }
    @Published var aiDialogue: Bool { didSet { d.set(aiDialogue, forKey: "aiDialogue") } }
    @Published var aiReactions: Bool { didSet { d.set(aiReactions, forKey: "aiReactions") } }
    @Published var aiBrain: Bool { didSet { d.set(aiBrain, forKey: "aiBrain") } }
    @Published var aiBanter: Bool { didSet { d.set(aiBanter, forKey: "aiBanter") } }
    @Published var aiMemory: Bool { didSet { d.set(aiMemory, forKey: "aiMemory") } }
    @Published var aiCommands: Bool { didSet { d.set(aiCommands, forKey: "aiCommands") } }
    /// Mirrors the system's login item (not stored here: macOS owns it).
    @Published var launchAtLogin = LoginItem.enabled

    /// Minutes between reminders of this kind, or nil when it is off.
    func interval(_ kind: ReminderKind) -> Int? {
        let m = reminderMinutes[kind.rawValue] ?? 0
        return m > 0 ? m : nil
    }

    private init() {
        species = Species(rawValue: d.string(forKey: "species") ?? "") ?? .mochi
        petSize = PetSize(rawValue: d.string(forKey: "petSize") ?? "") ?? .medium
        chattiness = Chattiness(rawValue: d.string(forKey: "chattiness") ?? "") ?? .normal
        walkOnWindows = d.object(forKey: "walkOnWindows") as? Bool ?? true
        climbEdges = d.object(forKey: "climbEdges") as? Bool ?? true
        followCursor = d.object(forKey: "followCursor") as? Bool ?? true
        reactToMedia = d.object(forKey: "reactToMedia") as? Bool ?? true
        reactToTyping = d.object(forKey: "reactToTyping") as? Bool ?? true
        secondPet = d.object(forKey: "secondPet") as? Bool ?? false
        companionSpecies = Species(rawValue: d.string(forKey: "companionSpecies") ?? "") ?? .cat
        outfit = Outfit(rawValue: d.string(forKey: "outfit") ?? "") ?? .none
        dailyCheckIn = d.object(forKey: "dailyCheckIn") as? Bool ?? true
        calendarAlerts = d.object(forKey: "calendarAlerts") as? Bool ?? false
        googleCalendarAlerts = d.object(forKey: "googleCalendarAlerts") as? Bool ?? true
        googleAlertAtStart = d.object(forKey: "googleAlertAtStart") as? Bool ?? true
        googleClientID = d.string(forKey: "googleClientID") ?? ""
        reminderMinutes = d.dictionary(forKey: "reminderMinutes") as? [String: Int] ?? [ReminderKind.water.rawValue: 60]
        breakReminders = d.object(forKey: "breakReminders") as? Bool ?? true
        breakMinutes = d.object(forKey: "breakMinutes") as? Int ?? 50
        quietOnCalls = d.object(forKey: "quietOnCalls") as? Bool ?? true
        reactToOtherAudio = d.object(forKey: "reactToOtherAudio") as? Bool ?? false
        systemAware = d.object(forKey: "systemAware") as? Bool ?? true
        aiEnabled = d.object(forKey: "aiEnabled") as? Bool ?? false
        aiBaseURL = d.string(forKey: "aiBaseURL") ?? "http://localhost:11434/v1"
        aiModel = d.string(forKey: "aiModel") ?? ""
        // Only look in the keychain once AI has been set up, so nobody else ever sees a keychain prompt.
        aiKey = d.object(forKey: "aiEnabled") != nil ? Keychain.read() : ""
        aiDialogue = d.object(forKey: "aiDialogue") as? Bool ?? true
        aiReactions = d.object(forKey: "aiReactions") as? Bool ?? true
        aiBrain = d.object(forKey: "aiBrain") as? Bool ?? true
        aiBanter = d.object(forKey: "aiBanter") as? Bool ?? true
        aiMemory = d.object(forKey: "aiMemory") as? Bool ?? true
        aiCommands = d.object(forKey: "aiCommands") as? Bool ?? true
    }
}
