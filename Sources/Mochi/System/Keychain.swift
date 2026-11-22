import Foundation
#if os(macOS)
import Security
#elseif os(Windows)
import WinSDK
#endif

/// Secrets live in the login keychain, not in the preferences file: the AI server's API key, and the
/// Google Calendar sign-in. Each has its own item, so reading one never touches the others.
enum Keychain {
    static let llm = "com.mochi.pet.llm"
    static let google = "com.mochi.pet.google"

#if os(macOS)
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
#elseif os(Windows)
    // Windows: the Credential Manager (Control Panel › Credential Manager › Windows Credentials), one
    // generic credential per secret, named "<service>/<account>", readable only by this Windows user.

    private static func target(_ service: String, _ account: String) -> [UInt16] {
        Array("\(service)/\(account)".utf16) + [0]
    }

    static func read(service: String = llm, account: String = "apiKey") -> String {
        var out: PCREDENTIALW?
        let name = target(service, account)
        guard CredReadW(name, DWORD(CRED_TYPE_GENERIC), 0, &out), let cred = out else { return "" }
        defer { CredFree(cred) }
        let size = Int(cred.pointee.CredentialBlobSize)
        guard size > 0, let blob = cred.pointee.CredentialBlob else { return "" }
        return String(decoding: UnsafeBufferPointer(start: blob, count: size), as: UTF8.self)
    }

    static func write(_ value: String, service: String = llm, account: String = "apiKey") {
        var name = target(service, account)
        guard !value.isEmpty else {
            _ = CredDeleteW(name, DWORD(CRED_TYPE_GENERIC), 0)
            return
        }
        var bytes = Array(value.utf8)
        var user = Array("Mochi".utf16) + [0]
        name.withUnsafeMutableBufferPointer { n in
            user.withUnsafeMutableBufferPointer { u in
                bytes.withUnsafeMutableBufferPointer { b in
                    var c = CREDENTIALW()
                    c.Type = DWORD(CRED_TYPE_GENERIC)
                    c.TargetName = n.baseAddress
                    c.UserName = u.baseAddress
                    c.CredentialBlobSize = DWORD(b.count)
                    c.CredentialBlob = b.baseAddress
                    c.Persist = DWORD(CRED_PERSIST_LOCAL_MACHINE)
                    _ = CredWriteW(&c, 0)
                }
            }
        }
    }
#endif
}
