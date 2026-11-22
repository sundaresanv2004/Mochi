#if os(macOS)
import SwiftUI

/// The compact card at the top of the menu bar dropdown: who the pet is and how it's doing.
struct MenuHeader: View {
    @ObservedObject var mind: PetMind
    let species: Species

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(species.name).font(.system(size: 13, weight: .semibold))
                Spacer()
                FeelingPill(feeling: mind.feeling)
            }
            HStack(spacing: 12) {
                Meter(symbol: "bolt.fill", label: "Energy", value: mind.energy, tint: .orange, showLabel: false)
                Meter(symbol: "fork.knife", label: "Tummy", value: mind.fullness, tint: .green, showLabel: false)
                Meter(symbol: "heart.fill", label: "Joy", value: mind.joy, tint: .pink, showLabel: false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .frame(width: 230)
    }
}

#endif
