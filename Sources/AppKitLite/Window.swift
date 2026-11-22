#if os(Windows)
import Foundation
import WinSDK
import LiteCanvas

public final class NSEvent {
    public enum EventType { case leftMouseDown, leftMouseUp, leftMouseDragged, rightMouseDown, rightMouseUp, mouseMoved, scrollWheel, keyDown, keyUp }

    public struct ModifierFlags: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let shift = ModifierFlags(rawValue: 1 << 17)
        public static let control = ModifierFlags(rawValue: 1 << 18)
        public static let option = ModifierFlags(rawValue: 1 << 19)
        public static let command = ModifierFlags(rawValue: 1 << 20)
        public static let deviceIndependentFlagsMask = ModifierFlags(rawValue: 0xffff0000)
    }

    public let type: EventType
    public let locationInWindow: NSPoint
    public let deltaX: CGFloat
    public let deltaY: CGFloat
    public let clickCount: Int
    public let modifierFlags: ModifierFlags
    public weak var window: NSWindow?
    public var buttonNumber: Int { type == .rightMouseDown || type == .rightMouseUp ? 1 : 0 }
    public var scrollingDeltaY: CGFloat { deltaY }
    public var timestamp: TimeInterval

    init(type: EventType, location: NSPoint, deltaX: CGFloat = 0, deltaY: CGFloat = 0, clickCount: Int = 1, window: NSWindow?) {
        self.type = type; locationInWindow = location; self.deltaX = deltaX; self.deltaY = deltaY
        self.clickCount = clickCount; self.window = window
        modifierFlags = NSEvent.modifierFlags
        timestamp = ProcessInfo.processInfo.systemUptime
    }

    /// Where the cursor is, in global points.
    public static var mouseLocation: NSPoint {
        var p = POINT()
        guard GetCursorPos(&p) else { return .zero }
        return Desktop.point(x: p.x, y: p.y)
    }

    /// Bit 0: left button held, bit 1: right button.
    public static var pressedMouseButtons: Int {
        var b = 0
        if GetAsyncKeyState(Int32(VK_LBUTTON)) & Int16(bitPattern: 0x8000) != 0 { b |= 1 }
        if GetAsyncKeyState(Int32(VK_RBUTTON)) & Int16(bitPattern: 0x8000) != 0 { b |= 2 }
        return b
    }

    public static var modifierFlags: ModifierFlags {
        var f: ModifierFlags = []
        func down(_ vk: Int32) -> Bool { GetKeyState(vk) & Int16(bitPattern: 0x8000) != 0 }
        if down(Int32(VK_SHIFT)) { f.insert(.shift) }
        if down(Int32(VK_CONTROL)) { f.insert(.control) }
        if down(Int32(VK_MENU)) { f.insert(.option) }
        if down(Int32(VK_LWIN)) || down(Int32(VK_RWIN)) { f.insert(.command) }
        return f
    }

    public static var doubleClickInterval: TimeInterval { TimeInterval(GetDoubleClickTime()) / 1000 }
}

/// A view that draws itself and takes mouse events. Only what Mochi's views need.
open class NSView {
    open var frame: NSRect
    public var bounds: NSRect { NSRect(origin: .zero, size: frame.size) }
    public internal(set) weak var window: NSWindow?
    open var menu: NSMenu?
    public var isHidden = false { didSet { needsDisplay = true } }
    public var alphaValue: CGFloat = 1
    public var wantsLayer = false
    public var toolTip: String?
    public var autoresizingMask: AutoresizingMask = []

    public struct AutoresizingMask: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let width = AutoresizingMask(rawValue: 2)
        public static let height = AutoresizingMask(rawValue: 16)
    }

    open var needsDisplay = false {
        didSet { if needsDisplay { window?.viewNeedsDisplay() } }
    }

    public init(frame: NSRect) { self.frame = frame }
    public convenience init() { self.init(frame: .zero) }

    open var isFlipped: Bool { false }
    open func draw(_ dirtyRect: NSRect) {}
    open func hitTest(_ point: NSPoint) -> NSView? { NSRect(origin: .zero, size: frame.size).contains(point) ? self : nil }
    open func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
    open func viewDidMoveToWindow() {}
    open func mouseDown(with event: NSEvent) {}
    open func mouseDragged(with event: NSEvent) {}
    open func mouseUp(with event: NSEvent) {}
    open func rightMouseDown(with event: NSEvent) {}
    open func rightMouseUp(with event: NSEvent) {}
    open func mouseMoved(with event: NSEvent) {}
    open func scrollWheel(with event: NSEvent) {}

    public func setNeedsDisplay(_ rect: NSRect) { needsDisplay = true }
    public func display() { window?.display() }

    public func convert(_ p: NSPoint, from view: NSView?) -> NSPoint { p }
    public func convert(_ p: NSPoint, to view: NSView?) -> NSPoint { p }
}

/// A label: one line of text (Mochi uses it for treat emoji).
open class NSTextField: NSView {
    public var stringValue: String { didSet { needsDisplay = true } }
    public var font: NSFont? = .systemFont(ofSize: 13) { didSet { needsDisplay = true } }
    public var alignment: NSTextAlignment = .natural { didSet { needsDisplay = true } }
    public var textColor: NSColor? = .black { didSet { needsDisplay = true } }
    public var isEditable = false
    public var isBordered = false
    public var drawsBackground = false
    public var backgroundColor: NSColor?

    public init(labelWithString s: String) {
        stringValue = s
        super.init(frame: .zero)
    }

    public override init(frame: NSRect) {
        stringValue = ""
        super.init(frame: frame)
    }

    open override func draw(_ dirtyRect: NSRect) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [.font: font ?? .systemFont(ofSize: 13),
                                                    .foregroundColor: textColor ?? .black, .paragraphStyle: style]
        let s = stringValue as NSString
        let h = s.size(withAttributes: attrs).height
        s.draw(in: NSRect(x: 0, y: bounds.height - h, width: bounds.width, height: h), withAttributes: attrs)
    }
}

private let LWS_POPUP: DWORD = 0x8000_0000
private let LWS_EX_LAYERED: DWORD = 0x0008_0000
private let LWS_EX_TOOLWINDOW: DWORD = 0x0000_0080
private let LWS_EX_TOPMOST: DWORD = 0x0000_0008
private let LWS_EX_NOACTIVATE: DWORD = 0x0800_0000
private let LWS_EX_TRANSPARENT: DWORD = 0x0000_0020
private let GWL_EXSTYLE_: Int32 = -20

let liteInstance = GetModuleHandleW(nil)

private var liteWindows: [HWND: NSWindow] = [:]
private var windowClassReady = false
private let windowClassName = Array("MochiLiteWindow".utf16) + [0]

private func liteWindowProc(_ hwnd: HWND?, _ msg: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT {
    if let hwnd, let w = liteWindows[hwnd], let r = w.handle(msg, wParam, lParam) { return r }
    return DefWindowProcW(hwnd, msg, wParam, lParam)
}

/// A borderless, see-through, always-on-top window drawn from a premultiplied bitmap (a layered window).
open class NSWindow {
    public struct StyleMask: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let borderless = StyleMask([])
        public static let titled = StyleMask(rawValue: 1)
        public static let closable = StyleMask(rawValue: 2)
        public static let miniaturizable = StyleMask(rawValue: 4)
        public static let resizable = StyleMask(rawValue: 8)
        public static let fullSizeContentView = StyleMask(rawValue: 1 << 15)
        public static let nonactivatingPanel = StyleMask(rawValue: 1 << 7)
    }
    public enum BackingStoreType { case buffered, retained, nonretained }
    public struct Level: RawRepresentable, Hashable, Comparable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public init(_ rawValue: Int) { self.rawValue = rawValue }
        public static let normal = Level(0)
        public static let floating = Level(3)
        public static let modalPanel = Level(8)
        public static let statusBar = Level(25)
        public static let popUpMenu = Level(101)
        public static let screenSaver = Level(1000)
        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }
    public struct CollectionBehavior: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let canJoinAllSpaces = CollectionBehavior(rawValue: 1)
        public static let moveToActiveSpace = CollectionBehavior(rawValue: 2)
        public static let transient = CollectionBehavior(rawValue: 8)
        public static let stationary = CollectionBehavior(rawValue: 16)
        public static let ignoresCycle = CollectionBehavior(rawValue: 64)
        public static let fullScreenAuxiliary = CollectionBehavior(rawValue: 256)
    }
    public enum AnimationBehavior { case `default`, none, documentWindow, utilityWindow, alertPanel }
    public struct OcclusionState: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let visible = OcclusionState(rawValue: 2)
    }

    public private(set) var frame: NSRect
    public var isOpaque = true
    public var backgroundColor: NSColor? = .white
    public var hasShadow = true
    public var level: Level = .normal { didSet { if isVisible { raise() } } }
    public var collectionBehavior: CollectionBehavior = []
    public var animationBehavior: AnimationBehavior = .default
    public var hidesOnDeactivate = false
    public var isReleasedWhenClosed = true
    public var title = ""
    public var alphaValue: CGFloat = 1 { didSet { needsDisplay = true } }
    public var ignoresMouseEvents = false { didSet { updateStyle() } }
    public private(set) var isVisible = false

    public var contentView: NSView? {
        didSet {
            oldValue?.window = nil
            contentView?.window = self
            contentView?.frame = NSRect(origin: .zero, size: frame.size)
            contentView?.viewDidMoveToWindow()
            needsDisplay = true
        }
    }

    public private(set) var hwnd: HWND?
    private var canvas: OpaquePointer?
    private var canvasSize = (Int32(0), Int32(0))
    var needsDisplay = false
    private var dragging = false
    private var lastDrag = POINT()

    public init(contentRect: NSRect, styleMask: StyleMask, backing: BackingStoreType, defer flag: Bool) {
        frame = contentRect
        NSApplication.shared.prepareWindows()
        Self.registerClass()
        hwnd = CreateWindowExW(LWS_EX_LAYERED | LWS_EX_TOOLWINDOW | LWS_EX_NOACTIVATE, windowClassName, nil, LWS_POPUP,
                               0, 0, 1, 1, nil, nil, liteInstance, nil)
        if let hwnd { liteWindows[hwnd] = self }
    }

    deinit {
        if let hwnd { liteWindows[hwnd] = nil; DestroyWindow(hwnd) }
        if let canvas { lc_destroy(canvas) }
    }

    private static func registerClass() {
        guard !windowClassReady else { return }
        windowClassReady = true
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.lpfnWndProc = { hwnd, msg, wParam, lParam in liteWindowProc(hwnd, msg, wParam, lParam) }
        wc.hInstance = liteInstance
        wc.hCursor = LoadCursorW(nil, UnsafePointer<WCHAR>(bitPattern: 32512))     // IDC_ARROW
        windowClassName.withUnsafeBufferPointer { wc.lpszClassName = $0.baseAddress; _ = RegisterClassExW(&wc) }
    }

    private func updateStyle() {
        guard let hwnd else { return }
        var ex = LWS_EX_LAYERED | LWS_EX_TOOLWINDOW | LWS_EX_NOACTIVATE
        if ignoresMouseEvents { ex |= LWS_EX_TRANSPARENT }
        if level >= .floating { ex |= LWS_EX_TOPMOST }
        _ = SetWindowLongPtrW(hwnd, GWL_EXSTYLE_, LONG_PTR(ex))
    }

    open func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// The display the window is mostly on.
    public var screen: NSScreen? {
        let all = NSScreen.screens
        let best = all.max { a, b in
            a.frame.intersection(frame).width * a.frame.intersection(frame).height
                < b.frame.intersection(frame).width * b.frame.intersection(frame).height
        }
        if let best, best.frame.intersects(frame) { return best }
        let c = NSPoint(x: frame.midX, y: frame.midY)
        return all.min { hypot($0.frame.midX - c.x, $0.frame.midY - c.y) < hypot($1.frame.midX - c.x, $1.frame.midY - c.y) }
    }

    public var occlusionState: OcclusionState { isVisible ? .visible : [] }
    public var isKeyWindow: Bool { false }

    public func setFrameOrigin(_ p: NSPoint) {
        let f = constrainFrameRect(NSRect(origin: p, size: frame.size), to: nil)
        guard f.origin != frame.origin else { return }
        frame.origin = f.origin
        move()
    }

    public func setFrame(_ r: NSRect, display flag: Bool) {
        let resized = r.size != frame.size
        frame = constrainFrameRect(r, to: nil)
        if resized {
            contentView?.frame = NSRect(origin: .zero, size: frame.size)
            needsDisplay = true
            if flag, isVisible { display() }
        } else {
            move()
        }
    }

    public func setFrame(_ r: NSRect, display flag: Bool, animate: Bool) { setFrame(r, display: flag) }

    public func setContentSize(_ s: NSSize) { setFrame(NSRect(origin: frame.origin, size: s), display: true) }

    private func move() {
        guard let hwnd, isVisible else { return }
        let r = Desktop.pixelRect(frame)
        _ = SetWindowPos(hwnd, nil, r.left, r.top, 0, 0, UINT(SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE))
    }

    private func raise() {
        guard let hwnd else { return }
        updateStyle()
        let after = level >= .floating ? HWND(bitPattern: -1) : HWND(bitPattern: 0)      // HWND_TOPMOST / HWND_TOP
        _ = SetWindowPos(hwnd, after, 0, 0, 0, 0, UINT(SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE))
    }

    public func orderFrontRegardless() {
        guard let hwnd else { return }
        let wasVisible = isVisible
        isVisible = true
        if !wasVisible || needsDisplay { display() }
        _ = ShowWindow(hwnd, SW_SHOWNOACTIVATE)
        raise()
    }

    public func orderFront(_ sender: Any?) { orderFrontRegardless() }
    public func makeKeyAndOrderFront(_ sender: Any?) { orderFrontRegardless() }

    public func orderOut(_ sender: Any?) {
        guard let hwnd, isVisible else { return }
        isVisible = false
        _ = ShowWindow(hwnd, SW_HIDE)
    }

    public func close() { orderOut(nil) }

    func viewNeedsDisplay() {
        needsDisplay = true
        NSApplication.shared.windowNeedsDisplay(self)
    }

    /// Draws the content view into the bitmap and hands it to Windows.
    public func display() {
        guard let hwnd, let view = contentView else { return }
        needsDisplay = false
        view.needsDisplay = false
        guard isVisible else { return }
        let s = Desktop.scale
        let r = Desktop.pixelRect(frame)
        let w = max(1, r.right - r.left), h = max(1, r.bottom - r.top)
        if canvas == nil || canvasSize != (w, h) {
            if let canvas { lc_destroy(canvas) }
            canvas = lc_create(w, h)
            canvasSize = (w, h)
        }
        guard let canvas, lc_begin(canvas) == 0 else { return }
        let ctx = NSGraphicsContext(canvas: canvas, base: LiteMatrix(a: s, b: 0, c: 0, d: -s, tx: 0, ty: frame.height * s))
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = ctx
        if !view.isHidden { view.draw(view.bounds) }
        NSGraphicsContext.current = previous
        _ = lc_end(canvas)

        var dst = POINT(x: r.left, y: r.top)
        var size = SIZE(cx: w, cy: h)
        var src = POINT(x: 0, y: 0)
        var blend = BLENDFUNCTION(BlendOp: BYTE(AC_SRC_OVER), BlendFlags: 0,
                                  SourceConstantAlpha: BYTE(max(0, min(255, alphaValue * 255))), AlphaFormat: BYTE(AC_SRC_ALPHA))
        let dc = lc_hdc(canvas).map { HDC(OpaquePointer($0)) }
        _ = UpdateLayeredWindow(hwnd, nil, &dst, &size, dc, &src, 0, &blend, DWORD(ULW_ALPHA))
    }

    // MARK: Mouse

    private func location() -> NSPoint {
        let m = NSEvent.mouseLocation
        return NSPoint(x: m.x - frame.minX, y: m.y - frame.minY)
    }

    func handle(_ msg: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT? {
        switch Int32(msg) {
        case WM_MOUSEACTIVATE:
            return LRESULT(MA_NOACTIVATE)
        case WM_LBUTTONDOWN:
            guard let view = contentView, view.hitTest(location()) != nil else { return 0 }
            SetCapture(hwnd)
            dragging = true
            _ = GetCursorPos(&lastDrag)
            view.mouseDown(with: NSEvent(type: .leftMouseDown, location: location(), window: self))
            return 0
        case WM_MOUSEMOVE:
            guard dragging, let view = contentView else { return 0 }
            var p = POINT()
            _ = GetCursorPos(&p)
            let s = Desktop.scale
            let dx = CGFloat(p.x - lastDrag.x) / s, dy = CGFloat(p.y - lastDrag.y) / s
            lastDrag = p
            if dx != 0 || dy != 0 {
                view.mouseDragged(with: NSEvent(type: .leftMouseDragged, location: location(), deltaX: dx, deltaY: dy, window: self))
            }
            return 0
        case WM_LBUTTONUP:
            guard dragging else { return 0 }
            dragging = false
            ReleaseCapture()
            contentView?.mouseUp(with: NSEvent(type: .leftMouseUp, location: location(), window: self))
            return 0
        case WM_CAPTURECHANGED:
            if dragging {
                dragging = false
                contentView?.mouseUp(with: NSEvent(type: .leftMouseUp, location: location(), window: self))
            }
            return 0
        case WM_RBUTTONDOWN:
            contentView?.rightMouseDown(with: NSEvent(type: .rightMouseDown, location: location(), window: self))
            return 0
        case WM_RBUTTONUP:
            guard let view = contentView else { return 0 }
            view.rightMouseUp(with: NSEvent(type: .rightMouseUp, location: location(), window: self))
            if let menu = view.menu { menu.popUpAtCursor() }
            return 0
        case WM_MOUSEWHEEL:
            let delta = CGFloat(Int16(truncatingIfNeeded: (wParam >> 16) & 0xffff)) / 120
            contentView?.scrollWheel(with: NSEvent(type: .scrollWheel, location: location(), deltaY: delta, window: self))
            return 0
        default:
            return nil
        }
    }
}

open class NSPanel: NSWindow {}
#endif
