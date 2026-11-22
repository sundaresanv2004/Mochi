#if os(Windows)
import Foundation
import WinSDK

extension AudioWatcher {
    /// Which apps are using the microphone right now, from Windows' own privacy record (the one behind
    /// the microphone icon in the taskbar). Media playback comes from the system media controls instead
    /// (see `NowPlaying`), so this is only ever used to notice calls.
    func audioProcesses() -> [AudioProcess] {
        MicrophoneUse.appsUsingMicrophone().map { AudioProcess(bundleID: $0, output: true, input: true) }
    }

    func defaultOutputRunning() -> Bool { false }
}

enum MicrophoneUse {
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
