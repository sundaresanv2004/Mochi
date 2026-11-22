#if os(macOS)
import AppKit

/// A small floating text box above the pet for typing a request. Enter sends it, Escape or clicking away closes it.
final class AskPanel: NSPanel, NSWindowDelegate, NSTextFieldDelegate {
    private let field = NSTextField()
    private var onSubmit: ((String) -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 340, height: 44),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        delegate = self

        let back = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 340, height: 44))
        back.material = .popover
        back.state = .active
        back.blendingMode = .behindWindow
        back.wantsLayer = true
        back.layer?.cornerRadius = 12
        back.layer?.masksToBounds = true
        contentView = back

        field.frame = NSRect(x: 14, y: 11, width: 312, height: 22)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 14)
        field.lineBreakMode = .byTruncatingHead
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.delegate = self
        field.setAccessibilityLabel("Ask your pet")
        back.addSubview(field)
    }

    override var canBecomeKey: Bool { true }

    /// Show the box centred above `point` (the pet), kept inside `screen`.
    func show(above point: NSPoint, in screen: NSRect, placeholder: String, onSubmit: @escaping (String) -> Void) {
        self.onSubmit = onSubmit
        field.stringValue = ""
        field.placeholderString = placeholder
        var origin = NSPoint(x: point.x - frame.width / 2, y: point.y)
        origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - frame.width - 8)
        if origin.y + frame.height > screen.maxY - 8 { origin.y = screen.maxY - frame.height - 8 }
        setFrameOrigin(origin)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(field)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            let text = field.stringValue
            let send = onSubmit
            orderOut(nil)
            send?(text)
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            orderOut(nil)
            return true
        }
        return false
    }

    func windowDidResignKey(_ notification: Notification) { orderOut(nil) }
}

#endif
