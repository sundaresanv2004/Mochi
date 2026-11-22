#if os(Windows)
import Foundation
import AppKitLite

/// The Windows app: the pets, an icon in the notification area with the same menu as on the Mac.
final class WindowsApp: NSApplicationDelegate {
    private static let shared = WindowsApp()
    private var pet: PetController!

    static func run() {
        let app = NSApplication.shared
        app.delegate = shared
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyCounter.shared.start()
        pet = PetController()
        pet.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DailyLog.shared.publish()
        PetMind.shared.save()
    }
}
#endif
