import SwiftUI
import AppKit

/// Test page: fire each reminder on demand, see what the pet thinks is going on, and stage two-pet meetings.
struct DebugTab: View {
    @ObservedObject var settings: PetSettings
    @ObservedObject var debug = PetDebug.shared
    @ObservedObject var mind = PetMind.shared

    private func fire(_ a: DebugAction) { debug.fire?(a) }

    private func tint(_ k: ReminderKind) -> Color {
        switch k {
        case .water: return .blue
        case .posture: return .green
        case .eyes: return .purple
        }
    }

    enum Pane: String, CaseIterable {
        case reminders = "Reminder tests", activity = "Live readings", meetings = "Pet meetings", log = "Event log"
    }

    @State private var pane: Pane

    init(settings: PetSettings, pane: Pane = .reminders) {
        self.settings = settings
        _pane = State(initialValue: pane)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 34, weight: .light))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(settings.species.name)’s activity").font(.headline)
                    Text(debug.petState.isEmpty ? "Waiting for a reading…" : debug.petState)
                        .font(.system(.callout, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                PetPreview(species: settings.species, outfit: settings.outfit)
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(LinearGradient(colors: [Color(red: 0.12, green: 0.23, blue: 0.32),
                                                 Color(red: 0.17, green: 0.39, blue: 0.42)],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16))

            Picker("Debug tools", selection: $pane) {
                ForEach(Pane.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            switch pane {
            case .reminders: reminderTests
            case .activity: readings
            case .meetings: meetings
            case .log: DebugLogView()
            }
        }
    }

    private var reminderTests: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ReminderKind.allCases) { kind in
                    testButton(kind.label, detail: debug.reminders[kind.rawValue] ?? "Waiting…",
                               symbol: kind.symbol, color: tint(kind), action: .reminder(kind))
                }
                testButton("Stretch break", detail: debug.reminders["stretch"] ?? "Waiting…",
                           symbol: "figure.cooldown", color: .orange, action: .stretch)
                testButton("Calendar alert", detail: "Sample event in 5 minutes",
                           symbol: "calendar", color: .red, action: .calendar)
                testButton("Daily check-in", detail: "Today’s recap", symbol: "chart.bar.fill",
                           color: .indigo, action: .checkIn)
            }
            Text("Run any test to show its reminder immediately, even when switched off.")
                .font(.caption).foregroundStyle(.secondary)
            CardSection(title: "Reminder clocks", footer: "Advance all enabled timers to test a scheduled reminder.") {
                SettingRow(symbol: "forward.fill", tint: .teal, title: "Skip ahead", subtitle: debug.reminderState) {
                    Button("5 min") { fire(.skip(minutes: 5)) }
                    Button("15 min") { fire(.skip(minutes: 15)) }
                }
            }
        }
    }

    private func testButton(_ title: String, detail: String, symbol: String, color: Color,
                            action: DebugAction) -> some View {
        Button { fire(action) } label: {
            HStack(spacing: 10) {
                IconBadge(symbol: symbol, tint: color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.fill").font(.caption).foregroundStyle(color)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 62)
            .modifier(SettingsSurface())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Test " + title)
        .accessibilityValue(detail)
    }

    private var readings: some View {
        VStack(alignment: .leading, spacing: 14) {
            notices
            needs
        }
    }

    private func need(_ symbol: String, _ tint: Color, _ title: String, _ value: Double, _ note: String) -> some View {
        SettingRow(symbol: symbol, tint: tint, title: title, subtitle: note) {
            level(value, tint)
        }
    }

    /// A plain bar and the percentage, lined up on the right of a row.
    private func level(_ value: Double, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.10))
                    Capsule().fill(tint).frame(width: max(5, geo.size.width * min(1, max(0, value))))
                }
            }
            .frame(width: 120, height: 6)
            Text("\(Int((value * 100).rounded()))%")
                .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }

    /// The numbers behind the feeling: the brain's thresholds are listed so you can see what is about to change.
    private var needs: some View {
        CardSection(title: "Needs", footer: "Saved every 30 seconds. The feeling shown in the menu is \(mind.feeling.label.lowercased()).") {
            need("bolt.fill", .yellow, "Energy", mind.energy, "Naps more below 25%, must sleep below 8%")
            RowDivider()
            need("fork.knife", .orange, "Tummy", mind.fullness, "Hungry below 20%")
            RowDivider()
            need("heart.fill", .pink, "Joy", mind.joy, "Lonely below 25%, joyful above 70%")
            RowDivider()
            SettingRow(symbol: "star.fill", tint: .purple, title: "Bond: \(mind.bondTitle)",
                       subtitle: mind.level < PetMind.maxLevel
                        ? "Level \(mind.level) of \(PetMind.maxLevel), on the way to level \(mind.level + 1) · \(Int(mind.bondXP)) XP · day \(mind.daysTogether)"
                        : "Top level · \(Int(mind.bondXP)) XP · day \(mind.daysTogether)") {
                level(mind.levelProgress, .purple)
            }
        }
    }

    private var notices: some View {
        CardSection(title: "What your pet notices") {
            SettingRow(symbol: "person.fill", tint: .blue, title: "Presence", subtitle: debug.presence) { EmptyView() }
            RowDivider()
            SettingRow(symbol: "speaker.wave.2.fill", tint: .pink,
                       title: debug.sound.isEmpty ? "Sound" : "Sound: \(debug.sound)",
                       subtitle: debug.soundApps.isEmpty ? "No app is using the speakers" : debug.soundApps.joined(separator: "\n")) {
                EmptyView()
            }
            RowDivider()
            SettingRow(symbol: "display.2", tint: .teal, title: "Displays", subtitle: debug.screens) {
                Button("Send to next display") { fire(.nextScreen) }
                    .disabled(NSScreen.screens.count < 2)
            }
        }
    }

    private var meetings: some View {
        CardSection(title: "Two pets", footer: debug.pets) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(SocialKind.allCases) { kind in
                    Button { fire(.meet(kind)) } label: { Text(kind.label).frame(maxWidth: .infinity) }
                }
            }
            .padding(12)
            .disabled(!settings.secondPet)
        }
    }
}
