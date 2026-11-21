import Foundation
import Security

/// Talks to any server that speaks the OpenAI chat-completions API: Ollama, LM Studio, llama.cpp,
/// OpenRouter, OpenAI itself… Only `POST {base}/chat/completions` and `GET {base}/models` are used.
enum LLMError: LocalizedError {
    case notConfigured
    case badURL
    case http(Int, String)
    case empty

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set a server address and a model first."
        case .badURL: return "That server address isn't a valid URL."
        case .http(let code, let body): return "The server answered \(code)\(body.isEmpty ? "" : ": \(body)")"
        case .empty: return "The model sent back nothing."
        }
    }
}

/// Lets one request through at a time: a local model can only think about one thing at once,
/// and a pet should never pile up a queue of paid calls either.
actor LLMGate {
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func enter(urgent: Bool) async {
        guard busy else { busy = true; return }
        await withCheckedContinuation { c in
            if urgent { waiters.insert(c, at: 0) } else { waiters.append(c) }
        }
    }

    func leave() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }
}

struct LLMClient {
    var baseURL: String
    var model: String
    var apiKey: String

    private static let gate = LLMGate()
    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 90
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    /// The address as typed, forgiving a trailing slash or a pasted full endpoint.
    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for tail in ["/chat/completions", "/models"] where s.hasSuffix(tail) { s.removeLast(tail.count) }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private func request(_ path: String) throws -> URLRequest {
        let base = Self.normalize(baseURL)
        guard !base.isEmpty else { throw LLMError.notConfigured }
        guard let url = URL(string: base + path), url.scheme != nil, url.host != nil else { throw LLMError.badURL }
        var r = URLRequest(url: url)
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { r.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        return r
    }

    private func send(_ r: URLRequest) async throws -> Data {
        let (data, response) = try await Self.session.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw LLMError.http(code, String(String(decoding: data, as: UTF8.self).prefix(200)))
        }
        return data
    }

    /// The model names the server offers.
    func models() async throws -> [String] {
        let data = try await send(try request("/models"))
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let list = root?["data"] as? [[String: Any]] ?? []
        return list.compactMap { $0["id"] as? String }
    }

    /// One system + user exchange; returns the reply text with any "thinking" stripped.
    func chat(system: String, user: String, maxTokens: Int = 300, temperature: Double = 0.9,
              urgent: Bool = false) async throws -> String {
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else { throw LLMError.notConfigured }
        var r = try request("/chat/completions")
        r.httpMethod = "POST"

        func body(_ tokenField: String, _ temp: Double?) throws -> Data {
            var b: [String: Any] = [
                "model": model.trimmingCharacters(in: .whitespaces),
                "messages": [["role": "system", "content": system], ["role": "user", "content": user]],
                "stream": false,
                tokenField: maxTokens
            ]
            if let temp { b["temperature"] = temp }
            return try JSONSerialization.data(withJSONObject: b)
        }

        await Self.gate.enter(urgent: urgent)
        let data: Data
        do {
            r.httpBody = try body("max_tokens", temperature)
            do {
                data = try await send(r)
            } catch LLMError.http(400, let msg) where msg.contains("max_completion_tokens") || msg.contains("temperature") {
                // Newer hosted models renamed the token limit and fix the temperature themselves.
                r.httpBody = try body("max_completion_tokens", nil)
                data = try await send(r)
            }
        } catch {
            await Self.gate.leave()
            throw error
        }
        await Self.gate.leave()

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (root?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
        let text = Self.stripThinking(message?["content"] as? String ?? "")
        guard !text.isEmpty else { throw LLMError.empty }
        return text
    }

    // MARK: Reading replies

    /// Local reasoning models put their scratch work in <think>…</think> before the answer.
    static func stripThinking(_ s: String) -> String {
        var out = s
        while let open = out.range(of: "<think>") {
            if let close = out.range(of: "</think>", range: open.upperBound..<out.endIndex) {
                out.removeSubrange(open.lowerBound..<close.upperBound)
            } else {
                out.removeSubrange(open.lowerBound..<out.endIndex)      // ran out of tokens mid-thought
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first JSON object or array in a reply, ignoring any chatter or code fences around it.
    static func json(in text: String) -> Any? {
        // Whichever bracket comes first is the outer one; try the other if that doesn't parse.
        var tries: [(String.Index, Character)] = []
        if let o = text.firstIndex(of: "{") { tries.append((o, "}")) }
        if let a = text.firstIndex(of: "[") { tries.append((a, "]")) }
        tries.sort { $0.0 < $1.0 }
        for (start, close) in tries {
            guard let end = text.lastIndex(of: close), start < end,
                  let data = String(text[start...end]).data(using: .utf8),
                  let value = try? JSONSerialization.jsonObject(with: data) else { continue }
            return value
        }
        return nil
    }

    /// A single spoken line: first line only, no quotes or speaker label, not too long.
    static func line(_ text: String, limit: Int = 110) -> String? {
        var s = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        s = s.trimmingCharacters(in: .whitespaces)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'`*"))
        s = s.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, !s.hasPrefix("{"), !s.hasPrefix("[") else { return nil }
        if s.count > limit { s = String(s.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…" }
        return s
    }
}

/// Secrets live in the login keychain, not in the preferences file: the AI server's API key, and the
/// Google Calendar sign-in. Each has its own item, so reading one never touches the others.
enum Keychain {
    static let llm = "com.mochi.pet.llm"
    static let google = "com.mochi.pet.google"

    static func read(service: String = llm, account: String = "apiKey") -> String {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func write(_ value: String, service: String = llm, account: String = "apiKey") {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
        guard !value.isEmpty else { return }
        var add = q
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}
