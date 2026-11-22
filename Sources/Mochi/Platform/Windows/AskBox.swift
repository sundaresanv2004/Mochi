#if os(Windows)
import Foundation
import WinSDK
import AppKitLite

/// "Ask Mochi…": a small text box above the pet. Enter sends, Esc or clicking elsewhere closes it.
final class AskBox {
    static let shared = AskBox()

    private var window: HWND?
    private var edit: HWND?
    private var font: HFONT?
    private var onSubmit: ((String) -> Void)?
    fileprivate var editProc: WNDPROC?
    private static let className = Array("MochiAskBox".utf16) + [0]

    /// `above` is the point (AppKit coordinates) the box sits over, kept inside `screen`.
    func show(above: NSPoint, in screen: NSRect, placeholder: String, onSubmit: @escaping (String) -> Void) {
        self.onSubmit = onSubmit
        make()
        guard let window, let edit else { return }
        let s = Desktop.scale
        let w: CGFloat = 340, h: CGFloat = 44
        let x = min(max(above.x - w / 2, screen.minX + 8), screen.maxX - w - 8)
        let y = min(above.y, screen.maxY - h - 8)
        let px = Desktop.pixelRect(NSRect(x: x, y: y, width: w, height: h))
        _ = SetWindowPos(window, HWND(bitPattern: -1), px.left, px.top, px.right - px.left, px.bottom - px.top, UINT(SWP_SHOWWINDOW))
        _ = SetWindowPos(edit, nil, Int32(12 * s), Int32(11 * s), px.right - px.left - Int32(24 * s), Int32(22 * s), UINT(SWP_NOZORDER))
        let cue = Array(placeholder.utf16) + [0]
        cue.withUnsafeBufferPointer { _ = SendMessageW(edit, 0x1501, 1, LPARAM(Int(bitPattern: $0.baseAddress))) }   // EM_SETCUEBANNER
        SetWindowTextW(edit, nil)
        // Windows only lets the app you're using take the keyboard: borrow its input queue for a moment.
        let foreground = GetForegroundWindow()
        let theirs = GetWindowThreadProcessId(foreground, nil), mine = GetCurrentThreadId()
        let attached = theirs != 0 && theirs != mine && AttachThreadInput(mine, theirs, true)
        _ = SetForegroundWindow(window)
        _ = BringWindowToTop(window)
        _ = SetFocus(edit)
        if attached { _ = AttachThreadInput(mine, theirs, false) }
        shownAt = Date()
    }

    /// Closing when another window is clicked waits a moment, so the menu closing doesn't count.
    fileprivate var shownAt = Date.distantPast

    func hide() {
        if let window { _ = ShowWindow(window, SW_HIDE) }
    }

    fileprivate func submit() {
        guard let edit else { return }
        var buf = [WCHAR](repeating: 0, count: 1024)
        let n = GetWindowTextW(edit, &buf, Int32(buf.count))
        let text = String(decoding: buf[0..<Int(max(0, n))], as: UTF16.self).trimmingCharacters(in: .whitespacesAndNewlines)
        hide()
        if !text.isEmpty { let f = onSubmit; DispatchQueue.main.async { f?(text) } }
    }

    private func make() {
        guard window == nil else { return }
        let instance = GetModuleHandleW(nil)
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.lpfnWndProc = { hwnd, msg, wParam, lParam in
            if msg == UINT(WM_ACTIVATE), wParam & 0xffff == 0, Date().timeIntervalSince(AskBox.shared.shownAt) > 0.5 {
                AskBox.shared.hide()                                                        // clicked elsewhere
            }
            return DefWindowProcW(hwnd, msg, wParam, lParam)
        }
        wc.hInstance = instance
        wc.hbrBackground = GetSysColorBrush(COLOR_WINDOW)
        wc.hCursor = LoadCursorW(nil, UnsafePointer<WCHAR>(bitPattern: 32512))
        Self.className.withUnsafeBufferPointer { wc.lpszClassName = $0.baseAddress; _ = RegisterClassExW(&wc) }
        window = CreateWindowExW(DWORD(WS_EX_TOPMOST | WS_EX_TOOLWINDOW), Self.className, nil,
                                 DWORD(bitPattern: Int32(bitPattern: 0x8000_0000)) | DWORD(WS_BORDER),
                                 0, 0, 340, 44, nil, nil, instance, nil)
        edit = "EDIT".withCString(encodedAs: UTF16.self) {
            CreateWindowExW(0, $0, nil, DWORD(WS_CHILD | WS_VISIBLE) | DWORD(ES_AUTOHSCROLL), 12, 11, 316, 22, window, nil, instance, nil)
        }
        font = "Segoe UI".withCString(encodedAs: UTF16.self) {
            CreateFontW(-Int32(15 * Desktop.scale), 0, 0, 0, FW_NORMAL, 0, 0, 0, DWORD(DEFAULT_CHARSET), 0, 0, DWORD(CLEARTYPE_QUALITY), 0, $0)
        }
        if let edit, let font {
            _ = SendMessageW(edit, UINT(WM_SETFONT), WPARAM(UInt(bitPattern: Int(bitPattern: UnsafeRawPointer(font)))), 1)
            // Catch Enter and Esc in the field.
            let old = SetWindowLongPtrW(edit, GWLP_WNDPROC, unsafeBitCast(askEditProc as WNDPROC, to: LONG_PTR.self))
            editProc = unsafeBitCast(old, to: WNDPROC.self)
        }
    }
}

private let askEditProc: WNDPROC = { hwnd, msg, wParam, lParam in
    if msg == UINT(WM_KEYDOWN) {
        if wParam == WPARAM(VK_RETURN) { AskBox.shared.submit(); return 0 }
        if wParam == WPARAM(VK_ESCAPE) { AskBox.shared.hide(); return 0 }
    }
    if msg == UINT(WM_CHAR), wParam == 13 || wParam == 27 { return 0 }                    // no beep
    return CallWindowProcW(AskBox.shared.editProc, hwnd, msg, wParam, lParam)
}
#endif
