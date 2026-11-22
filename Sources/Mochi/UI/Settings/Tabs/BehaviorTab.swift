#if os(macOS)
import SwiftUI

struct BehaviorTab: View {
    @ObservedObject var settings: PetSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Desktop movement").font(.headline)
                HStack(spacing: 10) {
                    movementCard(.windows, enabled: $settings.walkOnWindows)
                    movementCard(.edges, enabled: $settings.climbEdges)
                    movementCard(.cursor, enabled: $settings.followCursor)
                }
            }

            CardSection(title: "Sound and calls") {
                ToggleRow(symbol: "music.note", tint: .pink, title: "React to media",
                          subtitle: "Vibe to whatever is playing (Spotify, Music, YouTube in a browser…) and settle down for videos or calls.", isOn: $settings.reactToMedia)
                RowDivider()
                ToggleRow(symbol: "mic.fill", tint: .teal, title: "Stay quiet during calls",
                          subtitle: "Pause speech bubbles while a calling app uses your microphone.",
                          isOn: $settings.quietOnCalls)
                RowDivider()
                ToggleRow(symbol: "waveform", tint: .purple, title: "React to other audio",
                          subtitle: "Only if your Mac can't report what's playing: count any app with the speakers open, like games. Some apps keep them open while silent.",
                          isOn: $settings.reactToOtherAudio)
            }

            CardSection(title: "Keyboard and Mac",
                        footer: "Typing activity stays on your Mac. Mochi counts keystrokes without reading them.") {
                ToggleRow(symbol: "keyboard", tint: .indigo, title: "Bop along while I type",
                          isOn: $settings.reactToTyping)
                RowDivider()
                ToggleRow(symbol: "bolt.fill", tint: .orange, title: "Comment on my Mac",
                          subtitle: "Notice battery level, time of day and a busy processor.", isOn: $settings.systemAware)
            }
        }
    }

    private func movementCard(_ move: Movement, enabled: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: move.sky, startPoint: .topLeading, endPoint: .bottomTrailing)
                GeometryReader { geometry in
                    let w = geometry.size.width, h = geometry.size.height
                    switch move {
                    case .windows:
                        miniatureWindow.frame(width: w * 0.76, height: 40)
                            .position(x: w * 0.55, y: h - 1)
                        portrait.position(x: w * 0.52, y: h - 51)
                    case .edges:
                        miniatureWindow.frame(width: w * 0.68, height: 108)
                            .position(x: w * 0.81, y: h * 0.76)
                        portrait.rotationEffect(.degrees(-90))
                            .position(x: w * 0.47 - 17, y: h * 0.52)
                    case .cursor:
                        Path { path in
                            path.move(to: CGPoint(x: w * 0.40, y: h * 0.67))
                            path.addQuadCurve(to: CGPoint(x: w * 0.75, y: h * 0.36),
                                              control: CGPoint(x: w * 0.65, y: h * 0.79))
                        }
                        .stroke(.white.opacity(0.82), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
                        portrait.position(x: w * 0.32, y: h * 0.55)
                        Image(systemName: "cursorarrow").font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.white).shadow(radius: 1)
                            .position(x: w * 0.76, y: h * 0.36)
                    }
                }
            }
            .frame(height: 88)
            .clipped()
            .accessibilityHidden(true)

            Toggle(move.rawValue, isOn: enabled)
                .font(.system(size: 12, weight: .semibold))
                .toggleStyle(.switch).controlSize(.small)
                .padding(10)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .modifier(SettingsSurface())
        .help(move.hint)
    }

    private var portrait: some View {
        PetPreview(species: settings.species, outfit: settings.outfit)
            .frame(width: 62, height: 62)
    }

    private var miniatureWindow: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(.white.opacity(0.24))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.62)))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 3) {
                    ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.78)).frame(width: 3, height: 3) }
                }.padding(6)
            }
    }

    private enum Movement: String {
        case windows = "Walk on windows", edges = "Climb edges", cursor = "Chase cursor"

        var hint: String {
            switch self {
            case .windows: return "Walk and leap onto window tops, following them as they move."
            case .edges: return "Climb the sides of the screen and hang from the top."
            case .cursor: return "Occasionally follow the pointer."
            }
        }

        var sky: [Color] {
            switch self {
            case .windows: return [Color(red: 0.25, green: 0.34, blue: 0.65), Color(red: 0.62, green: 0.70, blue: 0.96)]
            case .edges: return [Color(red: 0.16, green: 0.44, blue: 0.49), Color(red: 0.53, green: 0.79, blue: 0.74)]
            case .cursor: return [Color(red: 0.55, green: 0.33, blue: 0.52), Color(red: 0.91, green: 0.66, blue: 0.67)]
            }
        }
    }
}

#endif
