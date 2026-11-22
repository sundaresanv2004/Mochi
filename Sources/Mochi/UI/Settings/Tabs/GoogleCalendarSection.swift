#if os(macOS)
import SwiftUI

/// Settings › Reminders: sign in to Google Calendar so the pet reads out each event's own notifications.
struct GoogleCalendarSection: View {
    @ObservedObject var settings: PetSettings
    @ObservedObject var google = GoogleCalendar.shared
    @State private var secret = ""

    var body: some View {
        CardSection(title: "Google Calendar",
                    footer: "Read-only. Mochi talks to Google directly from this Mac and keeps the sign-in in your Keychain. Event titles only appear in your pet’s bubble and are never sent to the AI server. If this account is also in the Calendar app, each reminder is still said only once.") {
            switch google.status {
            case .signedOut: signedOut
            case .signingIn: signingIn
            case .signedIn: signedIn
            }
        }
    }

    // MARK: Signed out

    @ViewBuilder private var signedOut: some View {
        SettingRow(symbol: "calendar.badge.plus", tint: .blue, title: "Connect Google Calendar",
                   subtitle: google.problem ?? "Your pet says each event’s reminders when they’re due: 10 minutes before, 30 minutes before, whatever you set in Google Calendar.") {
            Button("Sign in with Google…") { google.signIn() }
                .disabled(!google.hasClient)
        }
        if GoogleCalendar.bundledClientID.isEmpty {
            RowDivider()
            clientRows
        }
    }

    @ViewBuilder private var clientRows: some View {
        SettingRow(symbol: "key.horizontal.fill", tint: .gray, title: "OAuth client ID",
                   subtitle: "In Google Cloud Console, turn on the Google Calendar API and create an OAuth client of type “Desktop app”.") {
            TextField("…apps.googleusercontent.com", text: $settings.googleClientID)
                .textFieldStyle(.roundedBorder).frame(width: 240)
                .disableAutocorrection(true)
        }
        RowDivider()
        SettingRow(symbol: "lock.fill", tint: .gray, title: "Client secret") {
            SecureField("Saved in your Keychain", text: $secret)
                .textFieldStyle(.roundedBorder).frame(width: 240)
                .onChange(of: secret) { google.setClientSecret($0) }
        }
    }

    // MARK: Signing in

    private var signingIn: some View {
        SettingRow(symbol: "globe", tint: .blue, title: "Finish signing in in your browser",
                   subtitle: "Pick your Google account and allow Mochi to see your calendars. This page will update by itself.") {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Button("Cancel") { google.cancelSignIn() }
            }
        }
    }

    // MARK: Signed in

    @ViewBuilder private var signedIn: some View {
        SettingRow(symbol: "person.crop.circle.badge.checkmark", tint: .blue, title: google.email,
                   subtitle: syncLine) {
            HStack(spacing: 8) {
                Button(google.syncing ? "Syncing…" : "Sync Now") { google.sync() }.disabled(google.syncing)
                Button("Sign Out") { google.signOut() }
            }
        }
        RowDivider()
        ToggleRow(symbol: "bell.badge.fill", tint: .red, title: "Say my Google Calendar reminders",
                  subtitle: "At each event’s own notification times.", isOn: $settings.googleCalendarAlerts)
        RowDivider()
        ToggleRow(symbol: "play.circle.fill", tint: .green, title: "Also when an event starts",
                  subtitle: "Even if it has no notification at the start time.", isOn: $settings.googleAlertAtStart)
        if settings.googleCalendarAlerts {
            RowDivider()
            upNext
        }
    }

    private var syncLine: String {
        if let p = google.problem { return p }
        guard let t = google.lastSync else { return google.syncing ? "Fetching your events…" : "Not synced yet" }
        let n = google.events.count
        return "\(n == 1 ? "1 event" : "\(n) events") this week · synced \(t.formatted(.relative(presentation: .named)))"
    }

    private var upNext: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up next").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            let list = Array(google.upNext.prefix(4))
            if list.isEmpty {
                Text("No upcoming events with reminders in the next week.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(list) { e in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(e.title).font(.system(size: 13)).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(reminderText(e)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(whenText(e)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(minWidth: 110, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func reminderText(_ e: CalendarEvent) -> String {
        let times = e.reminders.filter { $0 > 0 }.map { Dialogue.inTime($0) }
        return times.isEmpty ? "at start" : "🔔 " + times.joined(separator: ", ")
    }

    private func whenText(_ e: CalendarEvent) -> String {
        if e.allDay { return e.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
        let sameDay = Calendar.current.isDateInToday(e.start)
        return sameDay ? e.start.formatted(date: .omitted, time: .shortened)
                       : e.start.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

#endif
