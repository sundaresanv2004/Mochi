#if os(Windows)
import Foundation
import WinSDK
import AppKitLite

/// The Windows side of `WindowScanner`: the taskbar and the windows the pet can stand on.
enum WindowsDesktop {
    /// Whether the taskbar is actually on screen. The work area keeps reserving its strip while an
    /// auto-hide taskbar slides away (or a full-screen app covers it), which would leave the pet on thin air.
    static func taskbarIsShowing() -> Bool {
        guard let bar = "Shell_TrayWnd".withCString(encodedAs: UTF16.self, { FindWindowW($0, nil) }),
              IsWindowVisible(bar) else { return false }
        var r = RECT()
        guard GetWindowRect(bar, &r) else { return true }
        let shown = Desktop.rect(r)
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(shown) }) else { return false }
        // An auto-hidden taskbar is parked almost entirely off the screen.
        let visible = screen.frame.intersection(shown)
        return visible.width > 20 && visible.height > 20
    }

    private static var found: [HWND] = []

    /// Visible, ordinary top-level windows from front to back, with the frames Windows draws (without
    /// the invisible resize borders), as platforms in AppKit coordinates.
    static func platforms(in f: NSRect) -> [Platform] {
        found = []
        _ = EnumWindows({ hwnd, _ in
            if let hwnd { WindowsDesktop.found.append(hwnd) }
            return true
        }, 0)
        let me = GetCurrentProcessId()
        var result: [Platform] = []
        var inFront: [NSRect] = []

        for hwnd in found {
            guard IsWindowVisible(hwnd), !IsIconic(hwnd) else { continue }
            var pid: DWORD = 0
            GetWindowThreadProcessId(hwnd, &pid)
            guard pid != me else { continue }
            let ex = DWORD(truncatingIfNeeded: GetWindowLongPtrW(hwnd, -20))       // GWL_EXSTYLE
            if ex & 0x80 != 0 { continue }                                          // WS_EX_TOOLWINDOW
            var cloaked: DWORD = 0
            if DwmGetWindowAttribute(hwnd, DWORD(DWMWA_CLOAKED.rawValue), &cloaked, DWORD(MemoryLayout<DWORD>.size)) == S_OK,
               cloaked != 0 { continue }                                            // on another virtual desktop, or a hidden UWP shell
            if isShell(hwnd) { continue }
            var r = RECT()
            if DwmGetWindowAttribute(hwnd, DWORD(DWMWA_EXTENDED_FRAME_BOUNDS.rawValue), &r, DWORD(MemoryLayout<RECT>.size)) != S_OK {
                guard GetWindowRect(hwnd, &r) else { continue }
            }
            let rect = Desktop.rect(r)
            guard rect.width > 0, rect.height > 0 else { continue }
            let alpha = layeredAlpha(hwnd, ex)
            if debug { print("  window \(className(hwnd)) \(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height)) ex=\(String(ex, radix: 16)) alpha=\(alpha)") }

            defer { inFront.append(rect) }
            guard alpha > 0.5, rect.width >= 240, rect.height >= 120 else { continue }

            let top = rect.maxY
            guard top <= f.maxY - 76, top >= f.minY + 40 else { continue }       // room for the pet above it
            guard rect.maxX > f.minX + 100, rect.minX < f.maxX - 100 else { continue }

            // Skip windows whose top edge is hidden behind another window.
            let probe = NSPoint(x: rect.midX, y: rect.maxY - 2)
            if inFront.contains(where: { $0.contains(probe) }) { continue }

            let lo = max(rect.minX + 24, f.minX + 52)
            let hi = min(rect.maxX - 24, f.maxX - 52)
            guard hi - lo >= 60 else { continue }
            let id = Int(truncatingIfNeeded: Int(bitPattern: UnsafeRawPointer(hwnd)) & 0x7fff_ffff)
            result.append(Platform(id: id == 0 ? 1 : id, minX: lo, maxX: hi, top: top))
        }
        return result
    }

    static var debug = ProcessInfo.processInfo.environment["MOCHI_DEBUG_WINDOWS"] != nil

    private static func className(_ hwnd: HWND) -> String {
        var buf = [WCHAR](repeating: 0, count: 128)
        let n = GetClassNameW(hwnd, &buf, Int32(buf.count))
        return String(decoding: buf[0..<Int(max(0, n))], as: UTF16.self)
    }

    /// The desktop, the taskbars and other shell surfaces aren't windows to stand on.
    private static func isShell(_ hwnd: HWND) -> Bool {
        let name = className(hwnd)
        return ["Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd", "NotifyIconOverflowWindow",
                "Windows.UI.Core.CoreWindow", "XamlExplorerHostIslandWindow", "TopLevelWindowForOverflowXamlIsland"].contains(name)
    }

    private static func layeredAlpha(_ hwnd: HWND, _ ex: DWORD) -> Double {
        guard ex & 0x0008_0000 != 0 else { return 1 }                             // WS_EX_LAYERED
        var key: COLORREF = 0, alpha: BYTE = 255, flags: DWORD = 0
        guard GetLayeredWindowAttributes(hwnd, &key, &alpha, &flags), flags & 2 != 0 else { return 1 }   // LWA_ALPHA
        return Double(alpha) / 255
    }
}
#endif
