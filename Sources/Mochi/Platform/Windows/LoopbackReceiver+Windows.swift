#if os(Windows)
import Foundation
import WinSDK

/// A tiny one-shot web server on 127.0.0.1 that catches Google's redirect after you sign in (Winsock).
/// It only listens on the loopback address, only while a sign-in is in progress, and stops after
/// the first proper reply (or three minutes).
final class LoopbackReceiver: @unchecked Sendable {      // state is guarded by `lock`
    private let lock = NSLock()
    private var listener: SOCKET = SOCKET(bitPattern: -1)
    private var replyWaiter: CheckedContinuation<[String: String], Error>?
    private var reply: Result<[String: String], Error>?
    private static var started = false

    func start() async throws -> UInt16 {
        if !Self.started {
            var data = WSADATA()
            _ = WSAStartup(0x0202, &data)
            Self.started = true
        }
        let s = socket(AF_INET, Int32(SOCK_STREAM), Int32(IPPROTO_TCP.rawValue))
        guard s != SOCKET(bitPattern: -1) else { throw GoogleError(message: "Couldn't start the sign-in.") }
        var addr = sockaddr_in()
        addr.sin_family = ADDRESS_FAMILY(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.S_un.S_addr = UInt32(0x7f00_0001).bigEndian
        let len = Int32(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, len) } }
        guard bound == 0, listen(s, 4) == 0 else { closesocket(s); throw GoogleError(message: "Couldn't start the sign-in.") }
        var got = sockaddr_in()
        var gotLen = len
        _ = withUnsafeMutablePointer(to: &got) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(s, $0, &gotLen) } }
        lock.lock(); listener = s; lock.unlock()

        Thread { [weak self] in self?.serve(s) }.start()
        DispatchQueue.global().asyncAfter(deadline: .now() + 180) { [weak self] in
            self?.finish(.failure(GoogleError(message: "The sign-in took too long. Please try again.")))
        }
        return UInt16(bigEndian: got.sin_port)
    }

    func waitForRedirect() async throws -> [String: String] {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<[String: String], Error>) in
            lock.lock()
            if let r = reply { lock.unlock(); c.resume(with: r) } else { replyWaiter = c; lock.unlock() }
        }
    }

    func cancel() { finish(.failure(GoogleError(message: "Sign-in was cancelled."))) }

    private func serve(_ s: SOCKET) {
        while true {
            let conn = accept(s, nil, nil)
            if conn == SOCKET(bitPattern: -1) { return }           // closed by `finish`
            var buf = [CChar](repeating: 0, count: 16_384)
            let n = buf.withUnsafeMutableBufferPointer { recv(conn, $0.baseAddress, Int32($0.count - 1), 0) }
            let request = n > 0 ? String(decoding: buf[0..<Int(n)].map { UInt8(bitPattern: $0) }, as: UTF8.self) : ""
            // "GET /?code=…&state=… HTTP/1.1"
            let target = request.split(separator: "\r\n").first?.split(separator: " ").dropFirst().first.map(String.init) ?? ""
            let items = URLComponents(string: "http://127.0.0.1\(target)")?.queryItems ?? []
            var query: [String: String] = [:]
            for i in items { query[i.name] = i.value ?? "" }
            let isReply = query["code"] != nil || query["error"] != nil
            let body = isReply
                ? "<!doctype html><meta charset=utf-8><title>Mochi</title><body style=\"font:16px 'Segoe UI',sans-serif;text-align:center;padding:60px\"><h2>🍡 All done!</h2><p>You can close this tab and go back to Mochi.</p>"
                : "Not found"
            let head = "HTTP/1.1 \(isReply ? "200 OK" : "404 Not Found")\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
            let out = Array((head + body).utf8)
            _ = out.withUnsafeBufferPointer { $0.withMemoryRebound(to: CChar.self) { send(conn, $0.baseAddress, Int32($0.count), 0) } }
            closesocket(conn)
            if isReply { finish(.success(query)); return }
        }
    }

    private func finish(_ result: Result<[String: String], Error>) {
        lock.lock()
        guard reply == nil else { lock.unlock(); return }
        reply = result
        let s = listener
        listener = SOCKET(bitPattern: -1)
        let waiter = replyWaiter
        replyWaiter = nil
        lock.unlock()
        if s != SOCKET(bitPattern: -1) { closesocket(s) }
        waiter?.resume(with: result)
    }
}
#endif
