#if os(Windows)
import Foundation

/// Windows has no calendar the app can read without being packaged, so local calendar alerts are off
/// there (the setting is hidden). Google Calendar works on Windows too.
final class CalendarWatcher {
    struct Alert {
        let title: String
        let minutes: Int        // 0 = starting now
    }

    static var canAsk: Bool { false }
    static var authorized: Bool { false }

    func requestAccess(_ done: @escaping (Bool) -> Void) { DispatchQueue.main.async { done(false) } }
    func due(now: Date = Date()) -> [Alert] { [] }
}
#endif
