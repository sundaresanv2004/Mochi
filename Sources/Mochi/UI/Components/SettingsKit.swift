#if os(macOS)
import SwiftUI
import AppKit

/// Building blocks shared by every settings page: cards, rows with a coloured icon, section titles.

/// Translucent navigation on recent systems, with a material fallback for older Macs.
struct NavigationGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var opaque

    @ViewBuilder func body(content: Content) -> some View {
        let shape = Rectangle()
        if opaque {
            content.background(Color(nsColor: .controlBackgroundColor), in: shape)
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26, *) {
                content.glassEffect(.regular, in: shape)
            } else {
                content.background(.regularMaterial, in: shape)
            }
            #else
            content.background(.regularMaterial, in: shape)
            #endif
        }
    }
}

struct SettingsSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var opaque
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 17, style: .continuous)
        content
            .background(Color(nsColor: .controlBackgroundColor).opacity(opaque ? 1 : 0.72), in: shape)
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.23 : 0.95), .primary.opacity(0.09)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                .allowsHitTesting(false))
            .shadow(color: .black.opacity(0.045), radius: 7, y: 3)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(SettingsSurface())
    }
}

/// A titled group: small heading, a card, and an optional note underneath.
struct CardSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            Card { content }
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 4)
            }
        }
    }
}

/// A rounded square with a white glyph, like the icons in System Settings.
struct IconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 26

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).fill(tint.gradient))
            .accessibilityHidden(true)
    }
}

/// One setting: icon, title, an optional line of explanation, and a control on the right.
struct SettingRow<Trailing: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(minHeight: 46)
    }
}

/// A switch row.
struct ToggleRow: View {
    let symbol: String
    let tint: Color
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(symbol: symbol, tint: tint, title: title, subtitle: subtitle) {
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

/// The hairline between two rows, lined up with their text.
struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 52) }
}

/// How the pet feels, as a small tinted capsule with a glyph.
struct FeelingPill: View {
    let feeling: Feeling

    var tint: Color {
        switch feeling {
        case .sleepy: return .indigo
        case .hungry: return .orange
        case .lonely: return .blue
        case .joyful: return .pink
        case .content: return .green
        }
    }

    var body: some View {
        Label(feeling.label, systemImage: feeling.symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.15)))
            .accessibilityLabel("Feeling \(feeling.label.lowercased())")
    }
}

#endif
