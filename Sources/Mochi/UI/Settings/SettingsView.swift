#if os(macOS)
import SwiftUI
import AppKit

enum SettingsPage: String, CaseIterable, Identifiable {
    case pet, behavior, reminders, today, ai, general, debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pet: return "Pet"
        case .behavior: return "Behavior"
        case .reminders: return "Reminders"
        case .today: return "Today"
        case .ai: return "AI"
        case .general: return "General"
        case .debug: return "Debug"
        }
    }

    var subtitle: String {
        switch self {
        case .pet: return "Who lives on your screen, and how they're doing"
        case .behavior: return "Where your pet goes and what it notices"
        case .reminders: return "Gentle nudges while you work"
        case .today: return "Your day in numbers"
        case .ai: return "Give your pet a language model to think and talk with"
        case .general: return "Size, speech and system options"
        case .debug: return "Test reminders and see what the pet notices"
        }
    }

    var symbol: String {
        switch self {
        case .pet: return "pawprint.fill"
        case .behavior: return "figure.walk"
        case .reminders: return "bell.fill"
        case .today: return "chart.bar.fill"
        case .ai: return "sparkles"
        case .general: return "gearshape.fill"
        case .debug: return "ladybug.fill"
        }
    }
}

/// Which page is showing. (An observable object rather than `@State`, which needs a macro plugin
/// the command-line toolchain doesn't ship.)
final class SettingsNav: ObservableObject {
    @Published var page: SettingsPage
    init(_ page: SettingsPage = .pet) { self.page = page }
}

/// The settings window: a sidebar of pages on the left, the chosen page on the right.
struct SettingsView: View {
    static let size = NSSize(width: 832, height: 650)

    @ObservedObject var settings: PetSettings
    @ObservedObject var mind = PetMind.shared
    var onSayHi: () -> Void
    var onBringBack: () -> Void
    var onTreat: () -> Void
    var onPlay: () -> Void
    @ObservedObject var nav: SettingsNav

    private var page: SettingsPage { nav.page }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(colors: [.indigo.opacity(0.14), .purple.opacity(0.045), .cyan.opacity(0.10)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.blue.opacity(0.13), .clear], center: .bottomLeading,
                               startRadius: 8, endRadius: 430)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                PetPreview(species: settings.species)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.species.name).font(.headline)
                    Text(mind.bondTitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 6)
            .padding(.bottom, 16)
            ForEach(SettingsPage.allCases) { item in
                if item == .general {
                    Divider().padding(.horizontal, 10).padding(.vertical, 12)
                }
                Button { nav.page = item } label: {
                    HStack(spacing: 11) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 21)
                            .foregroundStyle(page == item ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
                        Text(item.title)
                            .font(.system(size: 13, weight: page == item ? .semibold : .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Color.accentColor.opacity(page == item ? 0.13 : 0),
                                in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(page == item ? [.isSelected] : [])
                .padding(.bottom, 3)
            }
            Spacer()
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                Text("Mochi " + version).font(.caption2).foregroundStyle(.secondary)
                    .padding(.leading, 12).padding(.top, 9)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 42)
        .padding(.bottom, 16)
        .frame(width: 198)
        .modifier(NavigationGlass())
        .overlay(alignment: .trailing) { Divider() }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(page.title).font(.system(size: 30, weight: .bold, design: .rounded))
                Text(page.subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 18)

            ScrollView {
                Group {
                    switch page {
                    case .pet: PetTab(settings: settings, onSayHi: onSayHi, onTreat: onTreat, onPlay: onPlay)
                    case .behavior: BehaviorTab(settings: settings)
                    case .reminders: RemindersTab(settings: settings)
                    case .today: TodayTab(log: .shared)
                    case .ai: AITab(settings: settings)
                    case .general: GeneralTab(settings: settings, onBringBack: onBringBack)
                    case .debug: DebugTab(settings: settings)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
            .id(page)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#endif
