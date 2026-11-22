#if os(Windows)
import Foundation
import WinSDK

/// Runs a console program with no console window and streams what it prints (Foundation's `Process`
/// would open a console window for it, since Mochi itself has none).
final class HiddenProcess {
    static var powershell: String {
        let root = ProcessInfo.processInfo.environment["SystemRoot"] ?? "C:\\Windows"
        return root + "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    }

    /// PowerShell's -EncodedCommand: the script as base64 UTF-16LE (no quoting to get wrong).
    static func encode(_ script: String) -> String {
        var bytes: [UInt8] = []
        for u in script.utf16 { bytes.append(UInt8(u & 0xff)); bytes.append(UInt8(u >> 8)) }
        return Data(bytes).base64EncodedString()
    }

    let executable: String
    let arguments: [String]
    var onOutput: ((Data) -> Void)?
    var onExit: (() -> Void)?
    private var process: HANDLE?
    private var running = false

    init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    deinit { terminate() }

    private static func quote(_ a: String) -> String {
        guard a.isEmpty || a.contains(where: { $0 == " " || $0 == "\t" || $0 == "\"" }) else { return a }
        return "\"" + a.replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    func start() -> Bool {
        var sa = SECURITY_ATTRIBUTES(nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size), lpSecurityDescriptor: nil, bInheritHandle: true)
        var readEnd: HANDLE?, writeEnd: HANDLE?
        guard CreatePipe(&readEnd, &writeEnd, &sa, 0), let readEnd, let writeEnd else { return false }
        _ = SetHandleInformation(readEnd, DWORD(HANDLE_FLAG_INHERIT), 0)

        var si = STARTUPINFOW()
        si.cb = DWORD(MemoryLayout<STARTUPINFOW>.size)
        si.dwFlags = DWORD(STARTF_USESTDHANDLES)
        si.hStdOutput = writeEnd
        si.hStdError = writeEnd
        si.hStdInput = nil
        var pi = PROCESS_INFORMATION()
        var line = Array(([executable] + arguments).map(Self.quote).joined(separator: " ").utf16) + [0]
        let ok = line.withUnsafeMutableBufferPointer { buf in
            CreateProcessW(nil, buf.baseAddress, nil, nil, true, DWORD(CREATE_NO_WINDOW), nil, nil, &si, &pi)
        }
        CloseHandle(writeEnd)
        guard ok else { CloseHandle(readEnd); return false }
        CloseHandle(pi.hThread)
        process = pi.hProcess
        running = true

        let output = onOutput, exit = onExit
        let reader = Thread {
            var buf = [UInt8](repeating: 0, count: 4096)
            while true {
                var got: DWORD = 0
                let ok = buf.withUnsafeMutableBytes { ReadFile(readEnd, $0.baseAddress, DWORD($0.count), &got, nil) }
                if !ok || got == 0 { break }
                output?(Data(buf[0..<Int(got)]))
            }
            CloseHandle(readEnd)
            exit?()
        }
        reader.start()
        return true
    }

    func terminate() {
        guard running, let process else { return }
        running = false
        _ = TerminateProcess(process, 0)
        CloseHandle(process)
        self.process = nil
    }
}
#endif
