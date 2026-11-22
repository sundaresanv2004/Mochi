#if os(Windows)
import Foundation
import WinSDK

public enum NSControl {
    public enum StateValue { case on, off, mixed }
}

/// A menu item with a closure instead of a target and selector.
public final class NSMenuItem {
    public var title: String
    public var isEnabled = true
    public var state: NSControl.StateValue = .off
    public var submenu: NSMenu?
    public var tag = 0
    public var representedObject: Any?
    public var isHidden = false
    public let isSeparatorItem: Bool
    public var handler: (() -> Void)?
    public var toolTip: String?

    public init(title: String, handler: (() -> Void)? = nil) {
        self.title = title; self.handler = handler; isSeparatorItem = false
    }

    private init(separator: Bool) { title = ""; isSeparatorItem = separator }

    public static func separator() -> NSMenuItem { NSMenuItem(separator: true) }
}

public final class NSMenu {
    public var title: String
    public private(set) var items: [NSMenuItem] = []
    /// Called just before the menu opens, to bring the items up to date.
    public var willOpen: (() -> Void)?

    public init(title: String = "") { self.title = title }

    public func addItem(_ item: NSMenuItem) { items.append(item) }
    @discardableResult
    public func addItem(withTitle title: String, handler: (() -> Void)? = nil) -> NSMenuItem {
        let i = NSMenuItem(title: title, handler: handler)
        addItem(i)
        return i
    }
    public func insertItem(_ item: NSMenuItem, at index: Int) { items.insert(item, at: min(index, items.count)) }
    public func removeAllItems() { items.removeAll() }
    public func removeItem(_ item: NSMenuItem) { items.removeAll { $0 === item } }
    public var numberOfItems: Int { items.count }

    /// Shows the menu at the cursor and runs the chosen item's handler.
    public func popUpAtCursor() {
        willOpen?()
        var p = POINT()
        _ = GetCursorPos(&p)
        var actions: [UINT: NSMenuItem] = [:]
        var next: UINT = 1
        func build(_ menu: NSMenu) -> HMENU? {
            menu.willOpen.map { if menu !== self { $0() } }
            guard let h = CreatePopupMenu() else { return nil }
            for item in menu.items where !item.isHidden {
                if item.isSeparatorItem { _ = AppendMenuW(h, UINT(MF_SEPARATOR), 0, nil); continue }
                var flags = UINT(MF_STRING)
                if !item.isEnabled { flags |= UINT(MF_GRAYED) }
                if item.state == .on { flags |= UINT(MF_CHECKED) }
                let text = Array(item.title.replacingOccurrences(of: "&", with: "&&").utf16) + [0]
                if let sub = item.submenu, let hs = build(sub) {
                    _ = AppendMenuW(h, flags | UINT(MF_POPUP), UINT_PTR(UInt(bitPattern: Int(bitPattern: UnsafeRawPointer(hs)))), text)
                } else {
                    let id = next
                    next += 1
                    actions[id] = item
                    _ = AppendMenuW(h, flags, UINT_PTR(id), text)
                }
            }
            return h
        }
        guard let menu = build(self) else { return }
        let owner = NSApplication.shared.messageWindow
        NSApplication.shared.menuActions = actions
        _ = SetForegroundWindow(owner)
        // The chosen item arrives as WM_COMMAND (see NSApplication.handle).
        _ = TrackPopupMenuEx(menu, UINT(TPM_RIGHTBUTTON), p.x, p.y, owner, nil)
        _ = PostMessageW(owner, UINT(WM_NULL), 0, 0)
        DestroyMenu(menu)
    }
}
#endif
