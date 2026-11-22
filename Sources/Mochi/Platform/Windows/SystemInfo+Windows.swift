#if os(Windows)
import Foundation
import WinSDK

/// Small, permission-free facts about the PC and the person using it.
enum SystemInfo {
    /// Seconds since the last keyboard / mouse input.
    static func userIdleSeconds() -> TimeInterval {
        var info = LASTINPUTINFO()
        info.cbSize = UINT(MemoryLayout<LASTINPUTINFO>.size)
        guard GetLastInputInfo(&info) else { return 0 }
        return TimeInterval(GetTickCount() &- info.dwTime) / 1000
    }

    /// How many keys have been pressed since Mochi started (Windows keeps no such total, so Mochi counts
    /// them: only that a key went down, never which one). See `KeyCounter`.
    static func keyPressCount() -> UInt32 { KeyCounter.shared.count }

    /// Cumulative CPU time as (busy, total), for comparing two samples.
    static func cpuTicks() -> (busy: Double, total: Double)? {
        var idle = FILETIME(), kernel = FILETIME(), user = FILETIME()
        guard GetSystemTimes(&idle, &kernel, &user) else { return nil }
        func v(_ f: FILETIME) -> Double { Double(UInt64(f.dwHighDateTime) << 32 | UInt64(f.dwLowDateTime)) }
        let total = v(kernel) + v(user)          // kernel time includes idle time
        return (total - v(idle), total)
    }

    /// Battery level and whether it's charging (nil without a battery).
    static func battery() -> (level: Int, charging: Bool)? {
        var s = SYSTEM_POWER_STATUS()
        guard GetSystemPowerStatus(&s), s.BatteryFlag & 128 == 0, s.BatteryLifePercent <= 100 else { return nil }
        return (Int(s.BatteryLifePercent), s.ACLineStatus == 1)
    }
}

/// Counts key presses with a low-level keyboard hook. It never records which key was pressed.
final class KeyCounter {
    static let shared = KeyCounter()
    private(set) var count: UInt32 = 0
    private var hook: HHOOK?

    private init() {}

    /// Needs the main thread's message loop, so the app starts it once it is running.
    func start() {
        guard hook == nil else { return }
        hook = SetWindowsHookExW(WH_KEYBOARD_LL, { code, wParam, lParam in
            if code == HC_ACTION, wParam == WPARAM(WM_KEYDOWN) || wParam == WPARAM(WM_SYSKEYDOWN) {
                KeyCounter.shared.count &+= 1
            }
            return CallNextHookEx(nil, code, wParam, lParam)
        }, GetModuleHandleW(nil), 0)
    }

    func stop() {
        if let hook { UnhookWindowsHookEx(hook) }
        hook = nil
    }
}
#endif
