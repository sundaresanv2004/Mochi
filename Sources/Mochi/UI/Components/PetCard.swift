#if os(macOS)
import SwiftUI
import AppKit

struct PetCard: View {
    let species: Species
    let selected: Bool

    var body: some View {
        VStack(spacing: 1) {
            PetPreview(species: species)
                .frame(width: 58, height: 58)
            Text(species.name).font(.system(size: 12, weight: selected ? .semibold : .regular))
        }
        .padding(.top, 4)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

#endif
