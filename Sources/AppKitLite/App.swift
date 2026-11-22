#if os(Windows)
import Foundation
import WinSDK
import LiteCanvas

public protocol NSApplicationDelegate: AnyObject {
    func applicationDidFinishLaunching(_ notification: Notification)
    func applicationWillTerminate(_ notification: Notification)
}

extension NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {}
    public func applicationWillTerminate(_ notification: Notification) {}
}

public var NSApp: NSApplication { NSApplication.shared }

private let messageClassName = Array("MochiLiteMessages".utf16) + [0]
private let WM_TRAY: UINT = UINT(WM_APP) + 1
private let WM_WAKE: UINT = UINT(WM_APP) + 2

private func messageProc(_ hwnd: HWND?, _ msg: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT {
    if let r = NSApplication.shared.handle(msg, wParam, lParam) { return r }
    return DefWindowProcW(hwnd, msg, wParam, lParam)
}

/// The app: a Win32 message loop that also runs Foundation's main run loop (timers, the main queue).
public final class NSApplication {
    public static let shared = NSApplication()

    public enum ActivationPolicy { case regular, accessory, prohibited }

    public weak var delegate: NSApplicationDelegate?
    public private(set) var messageWindow: HWND?
    private var running = false
    private var pending: [ObjectIdentifier: NSWindow] = [:]
    private var taskbarCreated: UINT = 0
    /// Every Win32 message the app's hidden window gets (power, sessions, display changes…).
    public var onMessage: ((UINT, WPARAM, LPARAM) -> Void)?

    private init() {
        Desktop.prepare()
    }

    func prepareWindows() {
        guard messageWindow == nil else { return }
        var wc = WNDCLASSEXW()
        wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
        wc.lpfnWndProc = { hwnd, msg, wParam, lParam in messageProc(hwnd, msg, wParam, lParam) }
        wc.hInstance = liteInstance
        messageClassName.withUnsafeBufferPointer { wc.lpszClassName = $0.baseAddress; _ = RegisterClassExW(&wc) }
        messageWindow = CreateWindowExW(0, messageClassName, nil, 0x8000_0000, 0, 0, 0, 0, nil, nil, liteInstance, nil)
        taskbarCreated = "TaskbarCreated".withCString(encodedAs: UTF16.self) { RegisterWindowMessageW($0) }
        // Screen lock / switch user, and the display turning off, like NSWorkspace's notifications on the Mac.
        // WTSRegisterSessionNotification(hwnd, NOTIFY_FOR_THIS_SESSION), looked up at run time.
        if let lib = "wtsapi32.dll".withCString(encodedAs: UTF16.self, { LoadLibraryW($0) }),
           let f = GetProcAddress(lib, "WTSRegisterSessionNotification") {
            typealias Register = @convention(c) (HWND?, DWORD) -> WindowsBool
            _ = unsafeBitCast(f, to: Register.self)(messageWindow, 0)
        }
        var display = GUID(Data1: 0x6FE6_9556, Data2: 0x704A, Data3: 0x47A0,
                           Data4: (0x8F, 0x24, 0xC2, 0x8D, 0x93, 0x6F, 0xDA, 0x47))   // GUID_CONSOLE_DISPLAY_STATE
        _ = RegisterPowerSettingNotification(messageWindow, &display, 0)       // DEVICE_NOTIFY_WINDOW_HANDLE
    }

    /// Turns Windows power and session messages into NSWorkspace notifications.
    private func postPowerEvents(_ msg: UINT, _ wParam: WPARAM, _ lParam: LPARAM) {
        let ws = NSWorkspace.shared.notificationCenter
        func post(_ name: Notification.Name) { ws.post(name: name, object: nil) }
        switch msg {
        case 0x0218:                                                            // WM_POWERBROADCAST
            switch wParam {
            case 0x4: post(NSWorkspace.willSleepNotification)                   // PBT_APMSUSPEND
            case 0x7, 0x12: post(NSWorkspace.didWakeNotification)               // PBT_APMRESUMESUSPEND / AUTOMATIC
            case 0x8013:                                                        // PBT_POWERSETTINGCHANGE
                guard let setting = UnsafeRawPointer(bitPattern: Int(lParam)) else { return }
                // POWERBROADCAST_SETTING: a GUID (16 bytes), a length (4), then the data: 0 off, 1 on, 2 dimmed.
                let state = setting.load(fromByteOffset: 20, as: UInt32.self)
                post(state == 0 ? NSWorkspace.screensDidSleepNotification : NSWorkspace.screensDidWakeNotification)
            default: break
            }
        case 0x02B1:                                                            // WM_WTSSESSION_CHANGE
            switch wParam {
            case 0x7: post(NSWorkspace.screenLockedNotification)                // WTS_SESSION_LOCK
            case 0x8: post(NSWorkspace.screenUnlockedNotification)              // WTS_SESSION_UNLOCK
            case 0x2, 0x4: post(NSWorkspace.sessionDidResignActiveNotification) // console / remote disconnect
            case 0x1, 0x3: post(NSWorkspace.sessionDidBecomeActiveNotification) // console / remote connect
            default: break
            }
        default: break
        }
    }

    public func setActivationPolicy(_ policy: ActivationPolicy) {}
    public func activate(ignoringOtherApps: Bool) {}
    public func activate() {}

    func windowNeedsDisplay(_ w: NSWindow) { pending[ObjectIdentifier(w)] = w }

    /// Redraws every window that asked to be redrawn.
    public func displayPending() {
        guard !pending.isEmpty else { return }
        let list = Array(pending.values)
        pending.removeAll()
        for w in list where w.needsDisplay { w.display() }
    }

    public func run() {
        prepareWindows()
        running = true
        delegate?.applicationDidFinishLaunching(Notification(name: Notification.Name("NSApplicationDidFinishLaunchingNotification")))
        var msg = MSG()
        while running {
            while PeekMessageW(&msg, nil, 0, 0, UINT(PM_REMOVE)) {
                if msg.message == UINT(WM_QUIT) { running = false; break }
                TranslateMessage(&msg)
                DispatchMessageW(&msg)
            }
            guard running else { break }
            // Timers and work queued on the main queue.
            _ = RunLoop.main.run(mode: .default, before: Date())
            displayPending()
            _ = MsgWaitForMultipleObjects(0, nil, false, 8, DWORD(QS_ALLINPUT))
        }
        delegate?.applicationWillTerminate(Notification(name: Notification.Name("NSApplicationWillTerminateNotification")))
        tray?.remove()
    }

    public func terminate(_ sender: Any?) {
        running = false
        if let messageWindow { _ = PostMessageW(messageWindow, UINT(WM_NULL), 0, 0) }
        if !runningLoop { exit(0) }
    }

    private var runningLoop: Bool { running }

    // MARK: Tray icon

    public private(set) var tray: TrayIcon?

    public func installTray(_ icon: TrayIcon) {
        prepareWindows()
        tray = icon
        icon.add(owner: messageWindow, message: WM_TRAY)
    }

    /// The items of the menu that is open, by command id.
    var menuActions: [UINT: NSMenuItem] = [:]

    func handle(_ msg: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT? {
        if msg == UINT(WM_COMMAND), lParam == 0 {
            let id = UINT(wParam & 0xffff)
            if let item = menuActions[id], item.isEnabled {
                menuActions = [:]
                DispatchQueue.main.async { item.handler?() }
            }
            return 0
        }
        if msg == WM_TRAY {
            switch UINT(lParam & 0xffff) {
            case UINT(WM_LBUTTONUP): tray?.onClick?()
            case UINT(WM_RBUTTONUP), UINT(WM_CONTEXTMENU): tray?.onRightClick?()
            default: break
            }
            return 0
        }
        if msg == taskbarCreated, taskbarCreated != 0 {
            tray?.add(owner: messageWindow, message: WM_TRAY)
            return 0
        }
        if msg == UINT(WM_DISPLAYCHANGE) || msg == UINT(WM_DPICHANGED) || msg == UINT(WM_SETTINGCHANGE) {
            NSScreen.invalidate()
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        }
        postPowerEvents(msg, wParam, lParam)
        onMessage?(msg, wParam, lParam)
        return nil
    }

    public static let didChangeScreenParametersNotification = Notification.Name("NSApplicationDidChangeScreenParametersNotification")
}

/// An icon in the notification area (the system tray), drawn from a bitmap.
public final class TrayIcon {
    private var data = NOTIFYICONDATAW()
    private var added = false
    private var icon: HICON?
    public var onClick: (() -> Void)?
    public var onRightClick: (() -> Void)?
    public var tooltip: String { didSet { if added { update(flags: UINT(NIF_TIP | NIF_SHOWTIP)) } } }

    /// `draw` paints the icon on a `size`-point square (y up), like an NSView's draw.
    public init(tooltip: String, size: CGFloat = 16, draw: () -> Void) {
        self.tooltip = tooltip
        setImage(size: size, draw: draw)
    }

    public func setImage(size: CGFloat = 16, draw: () -> Void) {
        let s = Desktop.scale
        let px = Int32((size * s).rounded())
        guard let canvas = lc_create(px, px), lc_begin(canvas) == 0 else { return }
        let ctx = NSGraphicsContext(canvas: canvas, base: LiteMatrix(a: s, b: 0, c: 0, d: -s, tx: 0, ty: size * s))
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = ctx
        draw()
        NSGraphicsContext.current = previous
        _ = lc_end(canvas)
        let made = lc_make_icon(canvas).map { HICON(OpaquePointer($0)) }
        lc_destroy(canvas)
        if let old = icon { DestroyIcon(old) }
        icon = made
        if added { update(flags: UINT(NIF_ICON)) }
    }

    private func fillTip() {
        let tip = Array(tooltip.utf16.prefix(127)) + [0]
        withUnsafeMutableBytes(of: &data.szTip) { buf in
            buf.copyBytes(from: [UInt8](repeating: 0, count: buf.count))
            tip.withUnsafeBytes { buf.copyMemory(from: UnsafeRawBufferPointer(rebasing: $0.prefix(buf.count))) }
        }
    }

    func add(owner: HWND?, message: UINT) {
        data.cbSize = DWORD(MemoryLayout<NOTIFYICONDATAW>.size)
        data.hWnd = owner
        data.uID = 1
        data.uFlags = UINT(NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP)
        data.uCallbackMessage = message
        data.hIcon = icon
        fillTip()
        added = Shell_NotifyIconW(DWORD(NIM_ADD), &data)
        if !added { added = Shell_NotifyIconW(DWORD(NIM_MODIFY), &data) }
    }

    private func update(flags: UINT) {
        data.uFlags = flags
        data.hIcon = icon
        fillTip()
        _ = Shell_NotifyIconW(DWORD(NIM_MODIFY), &data)
    }

    func remove() {
        guard added else { return }
        _ = Shell_NotifyIconW(DWORD(NIM_DELETE), &data)
        added = false
    }
}

public final class NSRunningApplication {
    public let localizedName: String?
    public let bundleIdentifier: String?
    public let processIdentifier: Int32

    init(name: String?, id: String?, pid: Int32) { localizedName = name; bundleIdentifier = id; processIdentifier = pid }

    public static var current: NSRunningApplication {
        NSRunningApplication(name: "Mochi", id: "Mochi", pid: Int32(GetCurrentProcessId()))
    }

    /// Windows apps have no bundle identifiers: nothing is ever found.
    public static func runningApplications(withBundleIdentifier id: String) -> [NSRunningApplication] { [] }
}

public final class NSWorkspace {
    public static let shared = NSWorkspace()
    /// Posts sleep / wake and screen notifications (see the Windows app's power watcher).
    public let notificationCenter = NotificationCenter()

    public static let activeSpaceDidChangeNotification = Notification.Name("NSWorkspaceActiveSpaceDidChangeNotification")
    public static let willSleepNotification = Notification.Name("NSWorkspaceWillSleepNotification")
    public static let didWakeNotification = Notification.Name("NSWorkspaceDidWakeNotification")
    public static let screensDidSleepNotification = Notification.Name("NSWorkspaceScreensDidSleepNotification")
    public static let screensDidWakeNotification = Notification.Name("NSWorkspaceScreensDidWakeNotification")
    public static let sessionDidResignActiveNotification = Notification.Name("NSWorkspaceSessionDidResignActiveNotification")
    public static let sessionDidBecomeActiveNotification = Notification.Name("NSWorkspaceSessionDidBecomeActiveNotification")
    /// Windows only: the screen was locked / unlocked (on the Mac these come from the distributed center).
    public static let screenLockedNotification = Notification.Name("LiteScreenLocked")
    public static let screenUnlockedNotification = Notification.Name("LiteScreenUnlocked")

    public var frontmostApplication: NSRunningApplication? { nil }

    /// Opens a web page or file with its default app.
    @discardableResult
    public func open(_ url: URL) -> Bool {
        let target = url.isFileURL ? url.path : url.absoluteString
        let r = target.withCString(encodedAs: UTF16.self) { t in
            "open".withCString(encodedAs: UTF16.self) { verb in
                ShellExecuteW(nil, verb, t, nil, nil, SW_SHOWNORMAL)
            }
        }
        return Int(bitPattern: UnsafeRawPointer(r)) > 32
    }
}

extension ProcessInfo {
    /// Battery saver is on.
    public var isLowPowerModeEnabled: Bool {
        var s = SYSTEM_POWER_STATUS()
        return GetSystemPowerStatus(&s) && s.SystemStatusFlag == 1
    }
}
#endif

#if os(Windows)
extension ProcessInfo {
    public enum ThermalState: Int, Comparable {
        case nominal, fair, serious, critical
        public static func < (a: ThermalState, b: ThermalState) -> Bool { a.rawValue < b.rawValue }
    }
    /// Windows doesn't tell apps how hot the machine is running.
    public var thermalState: ThermalState { .nominal }
}
#endif
