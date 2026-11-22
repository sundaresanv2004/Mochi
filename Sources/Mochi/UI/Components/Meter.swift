#if os(macOS)
import SwiftUI

/// A thin capsule meter with an icon: one of the pet's needs.
struct Meter: View {
    let symbol: String
    let label: String
    let value: Double
    let tint: Color
    var showLabel = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel {
                Label(label, systemImage: symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                if !showLabel {
                    Image(systemName: symbol).font(.system(size: 9)).foregroundStyle(tint).frame(width: 11)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.10))
                        Capsule().fill(tint).frame(width: max(5, geo.size.width * min(1, max(0, value))))
                    }
                }
                .frame(height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(Int((value * 100).rounded())) percent")
    }
}

#endif
