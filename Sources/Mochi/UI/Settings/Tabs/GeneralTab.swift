#if os(macOS)
import SwiftUI

struct GeneralTab: View {
    @ObservedObject var settings: PetSettings
    var onBringBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Desktop pet size").font(.headline)
                HStack(spacing: 10) {
                    ForEach(PetSize.allCases) { size in
                        sizeOption(size)
                    }
                }
            }
            CardSection(title: "Voice") {
                SettingRow(symbol: "bubble.left.fill", tint: .green, title: "Speech bubbles") {
                    Picker("Speech bubbles", selection: $settings.chattiness) {
                        ForEach(Chattiness.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                }
                RowDivider()
                ToggleRow(symbol: "waveform", tint: .purple, title: "Listen for \u{201C}Hey \(settings.species.name)\u{201D}",
                          subtitle: "Then say what you'd like: \u{201C}Hey \(settings.species.name), do a dance\u{201D}. Speech is turned into text on this Mac and never recorded.",
                          isOn: $settings.voiceWake)
                RowDivider()
                SettingRow(symbol: "mic.fill", tint: .red, title: "Talk to \(settings.species.name)",
                           subtitle: "Or choose Talk to \(settings.species.name) in the menu (⌘L). Without AI it knows simple requests like dance, treat or sleep.") {
                    Button("Talk") { VoiceControl.shared.listenOnce(name: settings.species.name) }
                }
            }
            CardSection(title: "System") {
                SettingRow(symbol: "power", tint: .gray, title: "Launch at login",
                           subtitle: LoginItem.available ? nil : "Needs the built Mochi.app") {
                    Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                            set: { settings.launchAtLogin = LoginItem.set($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        .disabled(!LoginItem.available)
                }
                RowDivider()
                SettingRow(symbol: "arrow.uturn.backward", tint: .orange, title: "Lost your pet?",
                           subtitle: "Drops it back in from the top of the screen") {
                    Button("Bring back", action: onBringBack)
                }
            }
        }
    }

    private func sizeOption(_ size: PetSize) -> some View {
        let selected = settings.petSize == size
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        return Button { settings.petSize = size } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [.indigo.opacity(0.24), .cyan.opacity(0.12)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Capsule().fill(.primary.opacity(0.12)).frame(height: 2)
                        .padding(.horizontal, 18).padding(.bottom, 11)
                    PetPreview(species: settings.species, outfit: settings.outfit)
                        .frame(width: 94 * size.scale, height: 94 * size.scale)
                        .allowsHitTesting(false)
                }
                .frame(height: 94)
                HStack {
                    Text(size.label).font(.headline)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                }
                .padding(12)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(shape)
            .overlay(shape.strokeBorder(selected ? Color.accentColor : .primary.opacity(0.1),
                                       lineWidth: selected ? 2 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(size.label) pet size")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

}

#endif
