import SwiftUI

struct RemindersTab: View {
    @ObservedObject var settings: PetSettings

    private func isOn(_ k: ReminderKind) -> Binding<Bool> {
        Binding(get: { settings.interval(k) != nil },
                set: { settings.reminderMinutes[k.rawValue] = $0 ? k.defaultMinutes : 0 })
    }

    private func minutes(_ k: ReminderKind) -> Binding<Int> {
        Binding(get: { settings.interval(k) ?? k.defaultMinutes },
                set: { settings.reminderMinutes[k.rawValue] = $0 })
    }

    private func tint(_ k: ReminderKind) -> Color {
        switch k {
        case .water: return .blue
        case .posture: return .teal
        case .eyes: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scheduleSummary
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(ReminderKind.allCases) { kind in
                    scheduleCard(kind.label, symbol: kind.symbol, color: tint(kind),
                                 enabled: isOn(kind), interval: minutes(kind))
                }
                scheduleCard("Stretch break", symbol: "figure.cooldown", color: .orange,
                             enabled: $settings.breakReminders, interval: $settings.breakMinutes)
            }

            GoogleCalendarSection(settings: settings)

            CardSection(title: "Calendar and daily recap",
                        footer: "macOS asks for calendar access the first time you enable alerts. Event titles appear only in your pet’s bubble.") {
                ToggleRow(symbol: "calendar", tint: .red, title: "Calendar alerts",
                          subtitle: "Calendars in the Calendar app on this Mac: five minutes before an event and again when it starts.", isOn: $settings.calendarAlerts)
                RowDivider()
                ToggleRow(symbol: "chart.bar.fill", tint: .indigo, title: "Daily check-in",
                          subtitle: "A recap at 6 pm and the next morning.", isOn: $settings.dailyCheckIn)
            }
        }
    }

    private var scheduleSummary: some View {
        let count = ReminderKind.allCases.filter { settings.interval($0) != nil }.count
            + (settings.breakReminders ? 1 : 0)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(count == 1 ? "1 repeating reminder" : "\(count) repeating reminders")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Only time at your Mac counts. Reminders wait until calls and focus sessions end.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Menu {
                    ForEach(ReminderKind.allCases) { kind in
                        Button(kind.label) { PetDebug.shared.fire?(.reminder(kind)) }
                    }
                    Button("Stretch break") { PetDebug.shared.fire?(.stretch) }
                } label: {
                    Label("Try a reminder", systemImage: "bell.badge")
                }
                .fixedSize()
                .controlSize(.small)
                .environment(\.colorScheme, .dark)
                .padding(.top, 3)
            }
            Spacer(minLength: 0)
            ZStack {
                ForEach([68, 94, 122], id: \.self) { size in
                    Circle().stroke(.white.opacity(0.24), lineWidth: 1)
                        .frame(width: CGFloat(size), height: CGFloat(size))
                }
                PetPreview(species: settings.species, outfit: settings.outfit)
                    .frame(width: 76, height: 76)
            }
            .frame(width: 114, height: 88)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .foregroundStyle(.white)
        .background {
            LinearGradient(colors: [Color(red: 0.13, green: 0.21, blue: 0.40),
                                    Color(red: 0.24, green: 0.34, blue: 0.57),
                                    Color(red: 0.43, green: 0.51, blue: 0.68)],
                           startPoint: .leading, endPoint: .trailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func scheduleCard(_ title: String, symbol: String, color: Color,
                              enabled: Binding<Bool>, interval: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .medium, design: .rounded))
                .foregroundStyle(enabled.wrappedValue ? color : Color.secondary)
                .frame(width: 42, height: 50)
                .background((enabled.wrappedValue ? color : Color.secondary).opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if enabled.wrappedValue {
                    Menu {
                        Picker("\(title) interval", selection: interval) {
                            ForEach(ReminderKind.intervals, id: \.self) { value in
                                Text("Every \(value) min").tag(value)
                            }
                        }
                    } label: {
                        Text("\(interval.wrappedValue) min")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .accessibilityLabel("\(title) interval, every \(interval.wrappedValue) minutes")
                    .fixedSize()
                    .controlSize(.small)
                } else {
                    Text("Off").font(.caption).foregroundStyle(.secondary)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            Toggle(title, isOn: enabled)
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(alignment: .leading) {
            LinearGradient(colors: [color.opacity(enabled.wrappedValue ? 0.14 : 0.015), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .modifier(SettingsSurface())
    }
}
