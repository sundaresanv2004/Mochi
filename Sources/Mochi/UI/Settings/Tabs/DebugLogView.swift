import SwiftUI
import AppKit

/// The Debug page's event log: what the pets did and why, newest first, with filters, search and export.
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
        VStack(alignment: .leading, spacing: 10) {
            toolbar
            Card {
                if list.isEmpty {
                    Text(source.isEmpty ? "Nothing has happened yet. Events show up here as the pets go about their day."
                                        : "No events match the filter.")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .padding(14)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(list.reversed()) { e in
                                row(e)
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                    .frame(height: 360)
                }
            }
            Text(footer(list.count))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func footer(_ count: Int) -> String {
        var s = "Showing \(count) of \(source.count) events, newest first. The last \(DebugLog.capacity) are kept while Mochi runs; nothing is saved unless you save it."
        if frozen != nil { s = "Paused. " + s }
        return s
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search events", text: $search).textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))

            Menu {
                Button("Show all") { hidden = [] }
                Button("Hide all") { hidden = Set(DebugLog.Category.allCases) }
                Divider()
                ForEach(DebugLog.Category.allCases) { c in
                    Toggle(isOn: Binding(get: { !hidden.contains(c) },
                                         set: { on in if on { hidden.remove(c) } else { hidden.insert(c) } })) {
                        Label(c.label, systemImage: c.symbol)
                    }
                }
            } label: {
                Label(hidden.isEmpty ? "All events" : "\(DebugLog.Category.allCases.count - hidden.count) of \(DebugLog.Category.allCases.count) kinds",
                      systemImage: "line.3.horizontal.decrease.circle")
            }
            .fixedSize()

            Button { frozen = frozen == nil ? log.entries : nil } label: {
                Image(systemName: frozen == nil ? "pause.fill" : "play.fill")
            }
            .help(frozen == nil ? "Pause the list (events are still recorded)" : "Follow new events again")
            .accessibilityLabel(frozen == nil ? "Pause" : "Resume")

            Menu {
                Button("Copy shown events") { copy(shown) }
                Button("Copy everything") { copy(source) }
                Divider()
                Button("Save to a file…") { save(source) }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .fixedSize()
            .help("Copy or save the log for a bug report")
            .disabled(source.isEmpty)

            Button {
                log.clear()
                frozen = nil
                expanded = []
            } label: { Image(systemName: "trash") }
            .help("Clear the log")
            .accessibilityLabel("Clear the log")
            .disabled(log.entries.isEmpty)
        }
        .controlSize(.small)
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

    private func row(_ e: DebugLog.Entry) -> some View {
        let open = expanded.contains(e.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                IconBadge(symbol: e.category.symbol, tint: tint(e.category), size: 18)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                Text(DebugLog.clock.string(from: e.time))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                (Text(e.pet.map { "\($0)  " } ?? "").bold() + Text(e.message))
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Spacer(minLength: 4)
                if e.detail != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
            }
            if open, let d = e.detail {
                Text(d)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.leading, 26)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            guard e.detail != nil else { return }
            if open { expanded.remove(e.id) } else { expanded.insert(e.id) }
        }
        .accessibilityElement(children: .combine)
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
