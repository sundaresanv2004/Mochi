#if os(macOS)
import AppKit

/// Mochi runs without a Dock icon or menu bar, but text fields only get ⌘X / ⌘C / ⌘V / ⌘A / ⌘Z
/// through the key equivalents of the app's main menu. This menu is never shown; it only
/// routes those shortcuts to whichever field has focus (Settings › AI, Ask, …).
enum EditMenu {
    static func install() {
        let main = NSMenu()

        // AppKit treats the first item as the application menu; keep it empty.
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        NSApp.mainMenu = main
    }
}

#endif
