#if os(Windows)
import Foundation
import WinSDK

/// "Launch at login": the per-user Run key (Settings › Apps › Startup lists it too).
enum LoginItem {
    private static let runKey = "Software\\Microsoft\\Windows\\CurrentVersion\\Run"
    private static let name = "Mochi"

    /// Only the built Mochi.exe can be launched at login (not `swift run`'s debug build).
    static var available: Bool { !executable.lowercased().contains("\\.build\\") }

    static var executable: String {
        var buf = [WCHAR](repeating: 0, count: 1024)
        let n = GetModuleFileNameW(nil, &buf, DWORD(buf.count))
        return String(decoding: buf[0..<Int(n)], as: UTF16.self)
    }

    static var enabled: Bool {
        var size: DWORD = 0
        let r = runKey.withCString(encodedAs: UTF16.self) { key in
            name.withCString(encodedAs: UTF16.self) { RegGetValueW(HKEY_CURRENT_USER, key, $0, DWORD(RRF_RT_REG_SZ), nil, nil, &size) }
        }
        return r == ERROR_SUCCESS
    }

    /// Returns whether it is enabled afterwards.
    static func set(_ on: Bool) -> Bool {
        var key: HKEY?
        guard runKey.withCString(encodedAs: UTF16.self, { RegOpenKeyExW(HKEY_CURRENT_USER, $0, 0, REGSAM(0x0002), &key) }) == ERROR_SUCCESS,
              let key else { return enabled }
        defer { RegCloseKey(key) }
        if on, available {
            let value = Array("\"\(executable)\"".utf16) + [0]
            _ = name.withCString(encodedAs: UTF16.self) { n in
                value.withUnsafeBytes { RegSetValueExW(key, n, 0, DWORD(REG_SZ), $0.baseAddress?.assumingMemoryBound(to: BYTE.self), DWORD($0.count)) }
            }
        } else {
            _ = name.withCString(encodedAs: UTF16.self) { RegDeleteValueW(key, $0) }
        }
        return enabled
    }
}
#endif
