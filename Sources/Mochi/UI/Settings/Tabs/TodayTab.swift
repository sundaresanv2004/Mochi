#if os(macOS)
import SwiftUI

struct TodayTab: View {
    @ObservedObject var log: DailyLog
    @ObservedObject var settings = PetSettings.shared
    @AppStorage("bestRally") private var bestRally = 0
    @State private var showPrevious = false

    var body: some View {
        let previous = log.yesterday
        let day = showPrevious ? previous ?? log.today : log.today
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(displayDate(day.day), systemImage: "calendar")
                    .font(.callout.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                if previous != nil {
                    Picker("Activity day", selection: $showPrevious) {
                        Text("Today").tag(false)
                        Text(log.hasFreshYesterday ? "Yesterday" : "Previous day").tag(true)
                    }
                    .labelsHidden().pickerStyle(.segmented).fixedSize()
                }
            }
            dayPortrait(day)
            HStack(spacing: 10) {
                StatTile(symbol: "keyboard", value: DayStats.minutes(day.typingSeconds), label: "Typing", tint: .indigo)
                StatTile(symbol: "timer", value: "\(day.focusMinutes)m", label: day.focusSessions == 1 ? "1 focus session" : "\(day.focusSessions) focus sessions", tint: .purple)
                StatTile(symbol: "cup.and.saucer.fill", value: "\(day.breaks)", label: "Breaks", tint: .orange)
            }
            CardSection(title: "Pet time") {
                HStack(alignment: .top, spacing: 10) {
                    petStat("heart.fill", color: .pink, value: day.pets, label: "Pats")
                    Divider()
                    petStat("gift.fill", color: .orange, value: day.treats, label: "Treats")
                    Divider()
                    petStat("soccerball", color: .teal, value: day.plays, label: "Games played",
                            detail: "All-time best rally: \(bestRally)")
                }
                .padding(14)
            }
            if showPrevious && !day.isEmpty {
                Text(day.summary(prefix: log.hasFreshYesterday ? "Yesterday" : day.day))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Label("Only counts and durations are stored, on this Mac.", systemImage: "lock.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func displayDate(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return key }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func dayPortrait(_ day: DayStats) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Label("At your Mac", systemImage: "desktopcomputer")
                    .font(.headline)
                Text(DayStats.minutes(day.activeSeconds))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            Spacer()
            PetPreview(species: settings.species, outfit: settings.outfit)
                .frame(width: 100, height: 100)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 24)
        .frame(height: 122)
        .background {
            ZStack {
                LinearGradient(colors: [Color(red: 0.24, green: 0.19, blue: 0.36),
                                        Color(red: 0.54, green: 0.32, blue: 0.46),
                                        Color(red: 0.94, green: 0.65, blue: 0.48)],
                               startPoint: .leading, endPoint: .trailing)
                Canvas { context, size in
                    let w = size.width, h = size.height
                    let sun = CGPoint(x: w * 0.76, y: h * 0.32)
                    for radius in [48.0, 35.0, 23.0] {
                        let disk = CGRect(x: sun.x - radius, y: sun.y - radius, width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: disk), with: .color(.yellow.opacity(radius == 23 ? 0.62 : 0.11)))
                    }
                    var ridge = Path()
                    ridge.move(to: CGPoint(x: 0, y: h))
                    ridge.addQuadCurve(to: CGPoint(x: 0.64*w, y: 0.77*h), control: CGPoint(x: 0.43*w, y: 0.40*h))
                    ridge.addQuadCurve(to: CGPoint(x: w, y: 0.58*h), control: CGPoint(x: 0.82*w, y: 0.38*h))
                    ridge.addLine(to: CGPoint(x: w, y: h))
                    ridge.closeSubpath()
                    context.fill(ridge, with: .color(.indigo.opacity(0.28)))
                    context.fill(Path(ellipseIn: CGRect(x: w*0.44, y: h*0.81, width: w*0.86, height: h*0.82)),
                                 with: .color(.white.opacity(0.20)))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func petStat(_ symbol: String, color: Color, value: Int, label: String, detail: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
                .font(.title2)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.callout.weight(.medium))
                Text("\(value)").font(.system(size: 23, weight: .semibold, design: .rounded))
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#endif
