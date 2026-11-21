import SwiftUI
import AppKit

/// The Debug page's event log: what the pets did and why, newest first, with filters, search and export.
/// Laid out like the other settings pages: a titled card of rows, with a short note underneath.
struct DebugLogView: View {
    @ObservedObject var log = DebugLog.shared

    @State private var hidden: Set<DebugLog.Category> = []
    @State private var search = ""
    @State private var frozen: [DebugLog.Entry]?          // paused: a snapshot instead of the live list
    @State private var expanded: Set<Int> = []

    private var source: [DebugLog.Entry] { frozen ?? log.entries }

    /// What is shown, oldest first (the list itself shows them newest first).
    private var shown: [DebugLog.Entry] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return source.filter { e in
            guard !hidden.contains(e.category) else { return false }
            guard !q.isEmpty else { return true }
            return e.message.lowercased().contains(q) || (e.pet?.lowercased().contains(q) ?? false)
                || (e.detail?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        let list = shown
        CardSection(title: "Recent events", footer: footer(list.count)) {
            controls
            Divider()
            if list.isEmpty {
                Text(source.isEmpty ? "Nothing yet. Events show up here as the pets go about their day."
                                    : "No events match.")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(14)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(list.reversed().enumerated()), id: \.element.id) { i, e in
                            if i > 0 { Divider().padding(.leading, 48) }
                            row(e)
                        }
                    }
                }
                .frame(height: 340)
            }
        }
    }

    private func footer(_ count: Int) -> String {
        let what = count == source.count ? "\(count) events" : "\(count) of \(source.count) events"
        return (frozen == nil ? "" : "Paused. ")
            + "\(what), newest first. The last \(DebugLog.capacity) are kept until Mochi quits. Click an event with \u{203A} for its details."
    }

    // MARK: Controls

    private var filterLabel: String {
        let all = DebugLog.Category.allCases.count
        if hidden.isEmpty { return "All kinds" }
        if hidden.count == all - 1, let only = DebugLog.Category.allCases.first(where: { !hidden.contains($0) }) { return only.label }
        return "\(all - hidden.count) of \(all) kinds"
    }

    private var controls: some View {
        HStack(spacing: 10) {
            TextField("Search events", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            Menu(filterLabel) {
                Button("Show all") { hidden = [] }
                Divider()
                ForEach(DebugLog.Category.allCases) { c in
                    Toggle(isOn: Binding(get: { !hidden.contains(c) },
                                         set: { on in if on { hidden.remove(c) } else { hidden.insert(c) } })) {
                        Label(c.label, systemImage: c.symbol)
                    }
                }
                Divider()
                ForEach(DebugLog.Category.allCases) { c in
                    Button("Only \(c.label.lowercased())") { hidden = Set(DebugLog.Category.allCases).subtracting([c]) }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Kinds of event shown: \(filterLabel)")

            Button(frozen == nil ? "Pause" : "Resume") { frozen = frozen == nil ? log.entries : nil }
                .help(frozen == nil ? "Stop the list moving while you read (events are still recorded)" : "Follow new events again")

            Menu("Export") {
                Button("Copy shown events") { copy(shown) }
                Button("Copy all events") { copy(source) }
                Divider()
                Button("Save all to a file…") { save(source) }
            }
            .fixedSize()
            .disabled(source.isEmpty)

            Button("Clear") {
                log.clear()
                frozen = nil
                expanded = []
            }
            .disabled(log.entries.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(minHeight: 46)
    }

    // MARK: Rows

    private func tint(_ c: DebugLog.Category) -> Color {
        switch c {
        case .decision: return .blue
        case .speech: return .pink
        case .ai: return .purple
        case .media: return .orange
        case .reminder: return .green
        case .social: return .teal
        case .movement: return .indigo
        case .system: return .gray
        }
    }

    private func meta(_ e: DebugLog.Entry) -> String {
        [DebugLog.clock.string(from: e.time), e.pet, e.category.label].compactMap { $0 }.joined(separator: " · ")
    }

    private func row(_ e: DebugLog.Entry) -> some View {
        let open = expanded.contains(e.id)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 12) {
                IconBadge(symbol: e.category.symbol, tint: tint(e.category), size: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.message)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(meta(e))
                        .font(.caption).foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                if e.detail != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .padding(.top, 3)
                }
            }
            if open, let d = e.detail {
                Text(d)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.leading, 34)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            guard e.detail != nil else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                if open { expanded.remove(e.id) } else { expanded.insert(e.id) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(e.detail == nil ? [] : .isButton)
        .accessibilityHint(e.detail == nil ? "" : (open ? "Hides the details" : "Shows the details"))
    }

    // MARK: Export

    private func copy(_ list: [DebugLog.Entry]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(DebugLog.text(list), forType: .string)
    }

    private func save(_ list: [DebugLog.Entry]) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH.mm"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Mochi log \(f.string(from: Date())).txt"
        panel.allowedContentTypes = [.plainText]
        let text = DebugLog.text(list)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try text.write(to: url, atomically: true, encoding: .utf8) }
            catch { NSAlert(error: error).runModal() }
        }
    }
}
