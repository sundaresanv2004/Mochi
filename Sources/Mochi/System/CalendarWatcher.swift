#if os(macOS)
import EventKit
import Foundation

/// Looks a few minutes ahead in your calendar so the pet can warn you about meetings.
/// Off unless you turn it on, and only ever reads event titles and start times, on this Mac.
final class CalendarWatcher {
    struct Alert {
        let title: String
        let minutes: Int        // 0 = starting now
    }

    private let store = EKEventStore()
    private var announced = Set<String>()

    /// macOS only shows the permission prompt to apps that say why they want access.
    static var canAsk: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil
    }

    static var authorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) { return status == .fullAccess }
        return status == .authorized
    }

    /// Asks for calendar access if needed. `done` runs on the main queue.
    func requestAccess(_ done: @escaping (Bool) -> Void) {
        if Self.authorized { done(true); return }
        guard Self.canAsk else { done(false); return }
        let finish: (Bool, Error?) -> Void = { ok, _ in DispatchQueue.main.async { done(ok) } }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: finish)
        } else {
            store.requestAccess(to: .event, completion: finish)
        }
    }

    /// Events to announce right now: once about five minutes ahead, once as they start.
    func due(now: Date = Date()) -> [Alert] {
        guard Self.authorized else { return [] }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-60),
                                                 end: now.addingTimeInterval(6 * 60), calendars: nil)
        var alerts: [Alert] = []
        for e in store.events(matching: predicate) where !e.isAllDay {
            guard let start = e.startDate else { continue }
            let wait = start.timeIntervalSince(now)
            let id = "\(e.eventIdentifier ?? e.title ?? "event")@\(Int(start.timeIntervalSince1970))"
            let title = String((e.title ?? "Something").prefix(36))
            if wait <= 45, wait > -60 {
                if announced.insert(id + "#now").inserted { alerts.append(Alert(title: title, minutes: 0)) }
                announced.insert(id + "#soon")
            } else if wait <= 5.5 * 60, wait > 45 {
                if announced.insert(id + "#soon").inserted {
                    alerts.append(Alert(title: title, minutes: max(1, Int((wait / 60).rounded()))))
                }
            }
        }
        if announced.count > 400 { announced.removeAll() }
        return alerts
    }
}

#endif
