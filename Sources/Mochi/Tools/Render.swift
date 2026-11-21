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
        if let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
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

        // The Debug page's other panes, after a couple of simulated minutes so the event log has something in it.
        PetAI.shared.suspended = true
        let pet = PetController()
        pet.lastSlow = .distantFuture
        for _ in 0..<(120 * 30) { pet.tick(1.0 / 30) }
        for pane in [DebugTab.Pane.activity, .log] {
            let view = DebugTab(settings: s, pane: pane).padding(24).frame(width: SettingsView.size.width - 198)
            snapshot(view, to: path.replacingOccurrences(of: ".png", with: "-debug-\(pane == .log ? "log" : "readings").png"))
        }
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
