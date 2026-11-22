#if os(macOS)
import SwiftUI
import AppKit

/// Owns the settings window.
final class SettingsWindowController {
    private var window: NSWindow?
    private let nav = SettingsNav()
    private let onSayHi: () -> Void
    private let onBringBack: () -> Void
    private let onTreat: () -> Void
    private let onPlay: () -> Void

    init(onSayHi: @escaping () -> Void, onBringBack: @escaping () -> Void, onTreat: @escaping () -> Void,
         onPlay: @escaping () -> Void) {
        self.onSayHi = onSayHi
        self.onBringBack = onBringBack
        self.onTreat = onTreat
        self.onPlay = onPlay
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: .shared, onSayHi: onSayHi, onBringBack: onBringBack, onTreat: onTreat, onPlay: onPlay, nav: nav))
            let w = NSWindow(contentViewController: hosting)
            w.title = "Mochi Settings"
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titlebarSeparatorStyle = .none
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.setContentSize(SettingsView.size)
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

#endif
