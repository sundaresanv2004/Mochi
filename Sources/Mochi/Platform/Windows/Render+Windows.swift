#if os(Windows)
import Foundation
import AppKitLite

/// Developer helper: `Mochi --render sheet.png` writes the same contact sheets as on the Mac (every pet and
/// mood, plus one sheet per kind of media), drawn by the Windows drawing layer, for comparing the two.
enum Render {
    private static let cell = PetView.side

    /// Draws a pet set up by `setup` into the cell at column `col`, `rowFromTop` rows down.
    private static func pet(_ sheet: ImageCanvas, col: Int, rowFromTop: Int, _ setup: (PetView) -> Void) {
        let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
        setup(v)
        sheet.draw(at: NSPoint(x: CGFloat(col) * cell, y: sheet.size.height - cell * CGFloat(rowFromTop + 1))) {
            v.draw(v.bounds)
        }
    }

    private static func background(_ sheet: ImageCanvas) {
        sheet.draw {
            NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
            NSRect(origin: .zero, size: sheet.size).fill()
        }
    }

    static func run(to path: String) {
        let moods: [Mood] = [.idle, .walk, .happy, .sleep, .held, .dance, .stretch, .dizzy, .sad, .power]
        let rows = Species.allCases.count + 3
        guard let sheet = ImageCanvas(size: NSSize(width: cell * CGFloat(moods.count), height: cell * CGFloat(rows))) else { return }
        background(sheet)
        for (row, sp) in Species.allCases.enumerated() {
            for (col, m) in moods.enumerated() {
                pet(sheet, col: col, rowFromTop: row) { v in
                    v.species = sp; v.mood = m; v.time = m == .walk ? 0.15 : 0.6; v.facing = 1
                }
            }
        }
        // third row from the bottom: outfits, and a sweating pet
        let extras: [(Species, Outfit, Bool)] = [(.mochi, .flower, false), (.cat, .glasses, false), (.bunny, .partyHat, false),
                                                 (.penguin, .crown, false), (.ghost, .halo, false), (.mochi, .none, true),
                                                 (.dino, .cap, false), (.robot, .shades, false), (.dragon, .headband, false)]
        for (i, e) in extras.enumerated() {
            pet(sheet, col: i, rowFromTop: rows - 3) { v in
                v.species = e.0; v.outfit = e.1; v.sweat = e.2; v.mood = .idle; v.time = 0.6
            }
        }
        // second row from the bottom: wall / ceiling orientations for the penguin
        for (col, a) in [CGFloat(0), -.pi / 2, .pi / 2, .pi].enumerated() {
            pet(sheet, col: col, rowFromTop: rows - 2) { v in
                v.species = .penguin; v.mood = .idle; v.angle = a; v.time = 0.6
            }
        }
        // bottom row: vibing to music; every other pet lost in the song
        for (i, sp) in Species.allCases.enumerated() {
            pet(sheet, col: i, rowFromTop: rows - 1) { v in
                v.species = sp; v.mood = .idle; v.musicBpm = 120; v.time = i.isMultiple(of: 2) ? 0.45 : 7.1
            }
        }
        report(sheet.writePNG(to: path), path)
        media(to: path.replacingOccurrences(of: ".png", with: "-media.png"))
    }

    static func media(to path: String) {
        let pets = Species.allCases
        for kind in [MediaActivity.music, .podcast, .video, .movie, .other] {
            let acts = kind == .other ? MediaAct.privacy : MediaAct.acts(for: kind)
            guard let sheet = ImageCanvas(size: NSSize(width: cell * CGFloat(pets.count), height: cell * CGFloat(acts.count))) else { continue }
            background(sheet)
            for (row, act) in acts.enumerated() {
                for (col, sp) in pets.enumerated() {
                    pet(sheet, col: col, rowFromTop: row) { v in
                        v.species = sp; v.mood = .idle; v.facing = col.isMultiple(of: 3) ? -1 : 1; v.act = act
                        v.musicBpm = kind == .music ? 116 : 0
                        v.time = 0.55 + CGFloat(col) * 0.83 + CGFloat(row) * 0.37
                    }
                }
            }
            let name = kind == .other ? "private" : (kind == .movie ? "movie" : AudioWatcher.name(kind).lowercased())
            let out = path.replacingOccurrences(of: "-media.png", with: "-\(name).png")
            report(sheet.writePNG(to: out), out)
        }
    }

    private static func report(_ ok: Bool, _ path: String) { print(ok ? "wrote \(path)" : "couldn't write \(path)") }
}
#endif
