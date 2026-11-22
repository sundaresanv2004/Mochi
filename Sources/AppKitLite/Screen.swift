#if os(Windows)
import Foundation
import WinSDK

/// Converts between Windows screen pixels (origin top-left of the primary display, y down) and AppKit's
/// global points (origin bottom-left of the primary display, y up). One point is `scale` pixels, the
/// primary display's scale, everywhere.
public enum Desktop {
    private static var prepared = false

    /// Opts into per-monitor DPI so windows are drawn crisp. Must run before any window is made.
    public static func prepare() {
        guard !prepared else { return }
        prepared = true
        _ = SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT(bitPattern: -4))   // per monitor v2
        refresh()
    }

    public private(set) static var scale: CGFloat = 1
    private static var primaryHeight: CGFloat = 0          // pixels
    private static var refreshed = Date.distantPast

    static func refresh() {
        let primary = MonitorFromPoint(POINT(x: 0, y: 0), DWORD(MONITOR_DEFAULTTOPRIMARY))
        var dx: UINT = 96, dy: UINT = 96
        if GetDpiForMonitor(primary, MDT_EFFECTIVE_DPI, &dx, &dy) != S_OK { dx = GetDpiForSystem() }
        scale = max(1, CGFloat(dx) / 96)
        var info = MONITORINFO()
        info.cbSize = DWORD(MemoryLayout<MONITORINFO>.size)
        if GetMonitorInfoW(primary, &info) {
            primaryHeight = CGFloat(info.rcMonitor.bottom - info.rcMonitor.top)
        } else {
            primaryHeight = CGFloat(GetSystemMetrics(SM_CYSCREEN))
        }
        refreshed = Date()
    }

    static func refreshIfStale() {
        prepare()
        if Date().timeIntervalSince(refreshed) > 2 { refresh() }
    }

    public static func point(x: Int32, y: Int32) -> NSPoint {
        refreshIfStale()
        return NSPoint(x: CGFloat(x) / scale, y: (primaryHeight - CGFloat(y)) / scale)
    }

    public static func pixel(_ p: NSPoint) -> POINT {
        refreshIfStale()
        return POINT(x: Int32((p.x * scale).rounded()), y: Int32((primaryHeight - p.y * scale).rounded()))
    }

    public static func rect(_ r: RECT) -> NSRect {
        refreshIfStale()
        return NSRect(x: CGFloat(r.left) / scale, y: (primaryHeight - CGFloat(r.bottom)) / scale,
                      width: CGFloat(r.right - r.left) / scale, height: CGFloat(r.bottom - r.top) / scale)
    }

    /// The pixel rectangle (left, top, right, bottom) of a frame in points.
    public static func pixelRect(_ r: NSRect) -> RECT {
        let tl = pixel(NSPoint(x: r.minX, y: r.maxY))
        let w = Int32((r.width * scale).rounded(.up)), h = Int32((r.height * scale).rounded(.up))
        return RECT(left: tl.x, top: tl.y, right: tl.x + w, bottom: tl.y + h)
    }
}

/// A display, in AppKit's global coordinates.
public final class NSScreen: Equatable, Hashable, CustomStringConvertible {
    public let frame: NSRect
    public let visibleFrame: NSRect
    public let backingScaleFactor: CGFloat
    public let localizedName: String
    let monitor: Int

    init(monitor: HMONITOR, index: Int) {
        self.monitor = Int(bitPattern: UnsafeRawPointer(monitor))
        var info = MONITORINFO()
        info.cbSize = DWORD(MemoryLayout<MONITORINFO>.size)
        _ = GetMonitorInfoW(monitor, &info)
        frame = Desktop.rect(info.rcMonitor)
        visibleFrame = Desktop.rect(info.rcWork)
        var dx: UINT = 96, dy: UINT = 96
        _ = GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dx, &dy)
        backingScaleFactor = max(1, CGFloat(dx) / 96)
        localizedName = "Display \(index + 1)"
    }

    private static var cache: [NSScreen] = []
    private static var cachedAt = Date.distantPast
    fileprivate static var found: [HMONITOR] = []

    /// All displays, the primary first (like AppKit). Re-read at most twice a second.
    public static var screens: [NSScreen] {
        if Date().timeIntervalSince(cachedAt) < 0.5, !cache.isEmpty { return cache }
        Desktop.refreshIfStale()
        found = []
        _ = EnumDisplayMonitors(nil, nil, { monitor, _, _, _ in
            if let monitor { NSScreen.found.append(monitor) }
            return true
        }, 0)
        let primary = MonitorFromPoint(POINT(x: 0, y: 0), DWORD(MONITOR_DEFAULTTOPRIMARY))
        var list = found
        if let i = list.firstIndex(where: { $0 == primary }) { list.swapAt(0, i) }
        cache = list.enumerated().map { NSScreen(monitor: $0.element, index: $0.offset) }
        cachedAt = Date()
        return cache
    }

    /// Forget the cached list (the display layout changed).
    public static func invalidate() { cachedAt = .distantPast }

    /// The display with the window you're working in, or the primary one.
    public static var main: NSScreen? {
        let all = screens
        if let fg = GetForegroundWindow() {
            let m = MonitorFromWindow(fg, DWORD(MONITOR_DEFAULTTONULL))
            if let m, let s = all.first(where: { $0.monitor == Int(bitPattern: UnsafeRawPointer(m)) }) { return s }
        }
        return all.first
    }

    public static var deepest: NSScreen? { main }

    public static func == (a: NSScreen, b: NSScreen) -> Bool { a.monitor == b.monitor && a.frame == b.frame }
    public func hash(into h: inout Hasher) { h.combine(monitor) }
    public var description: String { "NSScreen(\(localizedName), frame \(frame), visible \(visibleFrame))" }
}
#endif
