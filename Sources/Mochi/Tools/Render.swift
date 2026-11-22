#if os(macOS)
import AppKit

/// Developer helper: `Mochi --render <dir>` writes a contact sheet of every pet and mood to a PNG.
enum Render {
    static func run(to path: String) {
        let moods: [Mood] = [.idle, .walk, .happy, .sleep, .held, .dance, .stretch, .dizzy, .sad, .power]
        let cell = PetView.side
        let sheet = NSImage(size: NSSize(width: cell * CGFloat(moods.count), height: cell * CGFloat(Species.allCases.count + 3)))
        sheet.lockFocus()
        NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
        NSRect(origin: .zero, size: sheet.size).fill()
        for (row, sp) in Species.allCases.enumerated() {
            for (col, m) in moods.enumerated() {
                let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
                v.species = sp; v.mood = m; v.time = 0.6; v.facing = 1
                if m == .walk { v.time = 0.15 }
                let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
                v.cacheDisplay(in: v.bounds, to: rep)
                let img = NSImage(size: v.bounds.size); img.addRepresentation(rep)
                img.draw(at: NSPoint(x: CGFloat(col) * cell, y: sheet.size.height - cell * CGFloat(row + 1)),
                         from: .zero, operation: .sourceOver, fraction: 1)
            }
        }
        // bottom row: wall / ceiling orientations for the penguin
        for (col, a) in [CGFloat(0), -.pi / 2, .pi / 2, .pi].enumerated() {
            let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
            v.species = .penguin; v.mood = .idle; v.angle = a; v.time = 0.6
            let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
            v.cacheDisplay(in: v.bounds, to: rep)
            let img = NSImage(size: v.bounds.size); img.addRepresentation(rep)
            img.draw(at: NSPoint(x: CGFloat(col) * cell, y: cell), from: .zero, operation: .sourceOver, fraction: 1)
        }
        for (i, sp) in Species.allCases.enumerated() {
            let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
            // Vibing to music; every other pet is caught lost in the song (eyes closed, see PetView.lostInMusic).
            v.species = sp; v.mood = .idle; v.musicBpm = 120; v.time = i.isMultiple(of: 2) ? 0.45 : 7.1
            let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
            v.cacheDisplay(in: v.bounds, to: rep)
            let img = NSImage(size: v.bounds.size); img.addRepresentation(rep)
            img.draw(at: NSPoint(x: CGFloat(i) * cell, y: 0), from: .zero, operation: .sourceOver, fraction: 1)
        }
        // third row from the bottom: outfits, and a sweating pet
        let extras: [(Species, Outfit, Bool)] = [(.mochi, .flower, false), (.cat, .glasses, false), (.bunny, .partyHat, false),
                                                 (.penguin, .crown, false), (.ghost, .halo, false), (.mochi, .none, true),
                                                 (.dino, .cap, false), (.robot, .shades, false), (.dragon, .headband, false)]
        for (i, e) in extras.enumerated() {
            let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
            v.species = e.0; v.outfit = e.1; v.sweat = e.2; v.mood = .idle; v.time = 0.6
            let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
            v.cacheDisplay(in: v.bounds, to: rep)
            let img = NSImage(size: v.bounds.size); img.addRepresentation(rep)
            img.draw(at: NSPoint(x: CGFloat(i) * cell, y: 2 * cell), from: .zero, operation: .sourceOver, fraction: 1)
        }
        sheet.unlockFocus()
        write(sheet, to: path)
        media(to: path.replacingOccurrences(of: ".png", with: "-media.png"))
    }

    /// One sheet per kind of media (…-music.png, …-podcast.png, …-video.png, …-movie.png): a row per act,
    /// a column per pet. Each column is caught at a different moment, so the animations show mid-move.
    static func media(to path: String) {
        let pets = Species.allCases
        let cell = PetView.side
        for kind in [MediaActivity.music, .podcast, .video, .movie, .other] {
            // `.other` stands in for the private-window acts (…-private.png).
            let acts = kind == .other ? MediaAct.privacy : MediaAct.acts(for: kind)
            let sheet = NSImage(size: NSSize(width: cell * CGFloat(pets.count), height: cell * CGFloat(acts.count)))
            sheet.lockFocus()
            NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
            NSRect(origin: .zero, size: sheet.size).fill()
            for (row, act) in acts.enumerated() {
                for (col, sp) in pets.enumerated() {
                    let v = PetView(frame: NSRect(origin: .zero, size: PetView.size))
                    v.species = sp; v.mood = .idle; v.facing = col.isMultiple(of: 3) ? -1 : 1; v.act = act
                    v.musicBpm = kind == .music ? 116 : 0
                    v.time = 0.55 + CGFloat(col) * 0.83 + CGFloat(row) * 0.37
                    let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
                    v.cacheDisplay(in: v.bounds, to: rep)
                    let img = NSImage(size: v.bounds.size); img.addRepresentation(rep)
                    img.draw(at: NSPoint(x: CGFloat(col) * cell, y: sheet.size.height - cell * CGFloat(row + 1)),
                             from: .zero, operation: .sourceOver, fraction: 1)
                }
            }
            sheet.unlockFocus()
            let name = kind == .other ? "private" : (kind == .movie ? "movie" : AudioWatcher.name(kind).lowercased())
            write(sheet, to: path.replacingOccurrences(of: "-media.png", with: "-\(name).png"))
        }
    }

    private static func write(_ image: NSImage, to path: String) {
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}

import SwiftUI

extension Render {
    /// Writes each settings tab and the menu header next to `path` (…-behavior.png, …-general.png, …-menu.png).
    static func settings(to path: String) {
        let s = PetSettings.shared
        for page in SettingsPage.allCases {
            let view = SettingsView(settings: s, onSayHi: {}, onBringBack: {}, onTreat: {}, onPlay: {}, nav: SettingsNav(page))
                .frame(width: SettingsView.size.width, height: SettingsView.size.height)
            snapshot(view, to: page == .pet ? path : path.replacingOccurrences(of: ".png", with: "-\(page.rawValue).png"))
        }
        snapshot(MenuHeader(mind: .shared, species: s.species), to: path.replacingOccurrences(of: ".png", with: "-menu.png"))
    }

    private static func snapshot<V: View>(_ view: V, to path: String) {
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: .aqua)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let win = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        win.contentView = host
        host.layoutSubtreeIfNeeded()
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)) }
    }
}

#endif
