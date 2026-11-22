#if os(macOS)
import SwiftUI
import AppKit

struct PetTab: View {
    @ObservedObject var settings: PetSettings
    @ObservedObject var mind = PetMind.shared
    var onSayHi: () -> Void
    var onTreat: () -> Void
    var onPlay: () -> Void

    @State private var browsingStyle: Species.Style?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Choose your pet").font(.headline)
                    Spacer()
                    Picker("Pet style", selection: Binding(
                        get: { browsingStyle ?? settings.species.style },
                        set: { browsingStyle = $0 }
                    )) {
                        Text("Cute").tag(Species.Style.cute)
                        Text("Tough").tag(Species.Style.tough)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 128)
                }
                group(browsingStyle ?? settings.species.style)
            }

            CardSection(title: "Wardrobe and friends") {
                SettingRow(symbol: "tshirt.fill", tint: .purple, title: "Outfit", subtitle: unlockHint) {
                    Picker("Outfit", selection: $settings.outfit) {
                        ForEach(Outfit.unlocked(at: mind.level)) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                RowDivider()
                ToggleRow(symbol: "person.2.fill", tint: .teal, title: "Second pet",
                          subtitle: "A friend that lives alongside \(settings.species.name)", isOn: $settings.secondPet)
                if settings.secondPet {
                    RowDivider()
                    SettingRow(symbol: "heart.fill", tint: .pink, title: "Friend") {
                        Picker("Friend", selection: $settings.companionSpecies) {
                            ForEach(Species.allCases) { Text($0.name).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
            }
        }
    }

    private var unlockHint: String? {
        guard let next = Outfit.next(after: mind.level) else { return nil }
        let names = Outfit.allCases.filter { $0.unlockLevel == next.unlockLevel }.map(\.label)
        return "Bond level \(next.unlockLevel) unlocks: \(names.joined(separator: ", "))"
    }

    private func group(_ style: Species.Style) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Species.allCases.filter { $0.style == style }) { sp in
                Button { settings.species = sp } label: {
                    PetCard(species: sp, selected: settings.species == sp)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(sp.name), \(sp.tagline)")
                .accessibilityAddTraits(settings.species == sp ? .isSelected : [])
            }
        }
    }

    private var hero: some View {
        let pet = settings.species
        return Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name).font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(pet.tagline).font(.callout)
                    Text("\(mind.bondTitle) · Level \(mind.level) · Day \(mind.daysTogether)")
                        .font(.caption.weight(.medium))
                        .padding(.top, 8)
                }
                .foregroundStyle(.white)
                Spacer()
                PetPreview(species: pet, outfit: settings.outfit)
                    .frame(width: 128, height: 128)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .background { habitat }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 16) {
                Meter(symbol: "bolt.fill", label: "Energy", value: mind.energy, tint: .orange)
                Meter(symbol: "fork.knife", label: "Tummy", value: mind.fullness, tint: .green)
                Meter(symbol: "heart.fill", label: "Joy", value: mind.joy, tint: .pink)
                Meter(symbol: "person.2.fill", label: "Bond", value: mind.levelProgress, tint: .purple)
            }
            .padding(16)
            Divider()
            HStack(spacing: 8) {
                FeelingPill(feeling: mind.feeling)
                Spacer()
                Button(action: onTreat) { Label("Give a treat", systemImage: "gift") }
                Button(action: onPlay) { Label("Play ball", systemImage: "soccerball") }
                Button(action: onSayHi) { Label("Say hi", systemImage: "hand.wave") }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var habitat: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.34),
                                    Color(red: 0.32, green: 0.36, blue: 0.61),
                                    Color(red: 0.88, green: 0.64, blue: 0.64)],
                           startPoint: .leading, endPoint: .trailing)
            Canvas { context, size in
                let w = size.width, h = size.height
                context.fill(Path(ellipseIn: CGRect(x: w * 0.72, y: 15, width: 31, height: 31)),
                             with: .color(Color(red: 1, green: 0.88, blue: 0.76)))
                for (x, y) in [(0.34, 0.20), (0.48, 0.31), (0.63, 0.15), (0.66, 0.38), (0.91, 0.19)] {
                    context.fill(Path(ellipseIn: CGRect(x: w*x, y: h*y, width: 2, height: 2)), with: .color(.white.opacity(0.8)))
                }
                var hills = Path()
                hills.move(to: CGPoint(x: 0, y: h))
                hills.addQuadCurve(to: CGPoint(x: w*0.58, y: h*0.78), control: CGPoint(x: w*0.32, y: h*0.28))
                hills.addQuadCurve(to: CGPoint(x: w, y: h*0.59), control: CGPoint(x: w*0.77, y: h*0.30))
                hills.addLine(to: CGPoint(x: w, y: h))
                hills.closeSubpath()
                context.fill(hills, with: .color(.indigo.opacity(0.34)))
                context.fill(Path(ellipseIn: CGRect(x: w*0.47, y: h*0.80, width: w*0.74, height: h*0.66)),
                             with: .color(.white.opacity(0.22)))
            }
        }
        .accessibilityHidden(true)
    }
}

#endif
