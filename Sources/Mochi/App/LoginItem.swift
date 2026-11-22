#if os(macOS)
import Foundation
import ServiceManagement

/// "Launch at login", via the system's login items. Only works from the built Mochi.app
/// (not from `swift run`), because macOS registers app bundles.
enum LoginItem {
    static var available: Bool { Bundle.main.bundleURL.pathExtension == "app" }
    static var enabled: Bool { available && SMAppService.mainApp.status == .enabled }

    /// Returns whether it is enabled afterwards.
    static func set(_ on: Bool) -> Bool {
        guard available else { return false }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Mochi: could not change the login item: \(error.localizedDescription)")
        }
        return enabled
    }
}

#endif
