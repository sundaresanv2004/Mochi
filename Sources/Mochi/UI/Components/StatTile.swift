#if os(macOS)
import SwiftUI

struct StatTile: View {
    let symbol: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(label).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .padding(12)
        .modifier(SettingsSurface())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

#endif
