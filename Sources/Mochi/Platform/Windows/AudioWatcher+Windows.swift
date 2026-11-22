#if os(Windows)
import Foundation
import WinSDK

extension AudioWatcher {
    /// Which apps are using the microphone right now, from Windows' own privacy record (the one behind
    /// the microphone icon in the taskbar). Media playback comes from the system media controls instead
    /// (see `NowPlaying`), so this is only ever used to notice calls.
    func audioProcesses() -> [AudioProcess] {
        MicrophoneUse.callAppsUsingMicrophone().map { AudioProcess(bundleID: $0, output: true, input: true) }
    }

    func defaultOutputRunning() -> Bool { false }
}

enum MicrophoneUse {
    /// Chat and meeting apps (as on the Mac, a browser with the microphone on isn't counted as a call).
    static let callApps = ["zoom", "teams", "discord", "slack", "skype", "webex", "whatsapp", "telegram", "signal",
                           "facetime", "ringcentral", "gotomeeting", "bluejeans", "jitsi", "element"]

    /// Call apps that have the microphone open right now. Windows leaves a stale "still using it" entry
    /// behind when an app quits mid-call, so only apps that are still running count.
    static func callAppsUsingMicrophone() -> [String] {
        let running = runningProcessNames()
        let apps = appsUsingMicrophone().filter { name in callApps.contains { name.contains($0) } }
            .filter { name in !name.hasSuffix(".exe") || running.contains(name) }
        return Array(Set(apps)).sorted()
    }

    private static func runningProcessNames() -> Set<String> {
        guard let snap = CreateToolhelp32Snapshot(DWORD(TH32CS_SNAPPROCESS), 0), snap != INVALID_HANDLE_VALUE else { return [] }
        defer { CloseHandle(snap) }
        var names = Set<String>()
        var e = PROCESSENTRY32W()
        e.dwSize = DWORD(MemoryLayout<PROCESSENTRY32W>.size)
        guard Process32FirstW(snap, &e) else { return [] }
        repeat {
            let name = withUnsafeBytes(of: e.szExeFile) { raw -> String in
                let u = raw.bindMemory(to: UInt16.self)
                return String(decoding: u.prefix { $0 != 0 }, as: UTF16.self)
            }
            names.insert(name.lowercased())
        } while Process32NextW(snap, &e)
        return names
    }

    private static let base = "Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\microphone"

    /// Lower-cased app names (exe names, or packaged apps' names) with the microphone open.
    static func appsUsingMicrophone() -> [String] {
        var found: [String] = []
        // Packaged apps sit directly under the key; desktop apps under "NonPackaged", named after their path.
        for (path, nonPackaged) in [(base, false), (base + "\\NonPackaged", true)] {
            for sub in subkeys(path) where sub != "NonPackaged" {
                guard let stop = qword(path + "\\" + sub, "LastUsedTimeStop"), stop == 0,
                      let start = qword(path + "\\" + sub, "LastUsedTimeStart"), start > 0 else { continue }
                let name = nonPackaged ? (sub.split(separator: "#").last.map(String.init) ?? sub) : sub
                found.append(name.lowercased())
            }
        }
        return found
    }

    private static func open(_ path: String) -> HKEY? {
        var key: HKEY?
        let r = path.withCString(encodedAs: UTF16.self) { RegOpenKeyExW(HKEY_CURRENT_USER, $0, 0, REGSAM(0x20019), &key) }
        return r == ERROR_SUCCESS ? key : nil
    }

    private static func subkeys(_ path: String) -> [String] {
        guard let key = open(path) else { return [] }
        defer { RegCloseKey(key) }
        var names: [String] = []
        var i: DWORD = 0
        var buf = [WCHAR](repeating: 0, count: 1024)
        while true {
            var len = DWORD(buf.count)
            let r = RegEnumKeyExW(key, i, &buf, &len, nil, nil, nil, nil)
            if r != ERROR_SUCCESS { break }
            names.append(String(decoding: buf[0..<Int(len)], as: UTF16.self))
            i += 1
        }
        return names
    }

    private static func qword(_ path: String, _ value: String) -> UInt64? {
        guard let key = open(path) else { return nil }
        defer { RegCloseKey(key) }
        var v: UInt64 = 0
        var size = DWORD(MemoryLayout<UInt64>.size)
        let r = value.withCString(encodedAs: UTF16.self) { name in
            withUnsafeMutableBytes(of: &v) { RegQueryValueExW(key, name, nil, nil, $0.baseAddress?.assumingMemoryBound(to: BYTE.self), &size) }
        }
        return r == ERROR_SUCCESS ? v : nil
    }
}
#endif
