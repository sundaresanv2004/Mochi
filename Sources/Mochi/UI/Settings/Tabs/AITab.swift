#if os(macOS)
import SwiftUI

/// Connect a language model (any server that speaks the OpenAI API) and choose what the pet uses it for.
struct AITab: View {
    @ObservedObject var settings: PetSettings
    @ObservedObject var ai = PetAI.shared
    @ObservedObject var memory = PetMemory.shared

    private var status: String {
        if ai.testing { return "Asking the server…" }
        if let r = ai.testResult { return r }
        if let e = ai.lastError { return "Last call failed: \(e)" }
        if let t = ai.lastReply {
            return "Last answer at \(DateFormatter.localizedString(from: t, dateStyle: .none, timeStyle: .short))"
        }
        return "Lists the server's models and asks for one word"
    }

    private enum Pane: String, CaseIterable {
        case connection = "Connection"
        case abilities = "Abilities"
        case journal = "Diary & memory"
    }

    @State private var pane: Pane = .connection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            assistantHeader
            Picker("AI settings section", selection: $pane) {
                ForEach(Pane.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch pane {
            case .connection: connection
            case .abilities: abilities
            case .journal: journal
            }
        }
    }

    private var assistantHeader: some View {
        HStack(spacing: 18) {
            ZStack {
                Canvas { context, size in
                    let points = [CGPoint(x: 6, y: 52), CGPoint(x: 21, y: 18),
                                  CGPoint(x: 56, y: 7), CGPoint(x: 81, y: 31),
                                  CGPoint(x: 74, y: 70)]
                    var path = Path()
                    path.addLines(points)
                    context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1)
                    for point in points {
                        context.fill(Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
                                     with: .color(.white.opacity(0.9)))
                    }
                }
                PetPreview(species: settings.species, outfit: settings.outfit)
                    .frame(width: 65, height: 65)
            }
            .frame(width: 86, height: 80)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(settings.aiEnabled ? "AI enabled" : "Built-in mode")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text(settings.aiEnabled
                     ? (settings.aiModel.isEmpty ? "Choose a model in Connection." : settings.aiModel)
                     : "\(settings.species.name) uses its built-in lines and instincts.")
                    .font(.callout).lineLimit(2)
            }
            .foregroundStyle(.white)
            Spacer(minLength: 4)
            Toggle("Use AI", isOn: $settings.aiEnabled)
                .toggleStyle(.switch).font(.headline)
                .environment(\.colorScheme, .dark)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background {
            LinearGradient(colors: [Color(red: 0.31, green: 0.24, blue: 0.51),
                                    Color(red: 0.19, green: 0.22, blue: 0.43),
                                    Color(red: 0.16, green: 0.32, blue: 0.41)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardSection(title: "Model connection",
                        footer: "Use an OpenAI-compatible endpoint such as Ollama, LM Studio, llama.cpp, OpenRouter or OpenAI. API keys are saved in your Mac’s Keychain.") {
                SettingRow(symbol: "network", tint: .blue, title: "Server") {
                    TextField("http://localhost:11434/v1", text: $settings.aiBaseURL)
                        .textFieldStyle(.roundedBorder).frame(width: 270)
                        .disableAutocorrection(true)
                }
                RowDivider()
                SettingRow(symbol: "cpu", tint: .indigo, title: "Model") {
                    TextField("llama3.2, gpt-4o-mini…", text: $settings.aiModel)
                        .textFieldStyle(.roundedBorder).frame(width: ai.models.isEmpty ? 270 : 236)
                        .disableAutocorrection(true)
                    if !ai.models.isEmpty {
                        Menu {
                            ForEach(ai.models, id: \.self) { m in Button(m) { settings.aiModel = m } }
                        } label: { Image(systemName: "chevron.down") }
                            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 26)
                            .accessibilityLabel("Choose a model from the server")
                    }
                }
                RowDivider()
                SettingRow(symbol: "key.fill", tint: .orange, title: "API key") {
                    SecureField("Not needed for local servers", text: $settings.aiKey)
                        .textFieldStyle(.roundedBorder).frame(width: 270)
                }
                RowDivider()
                SettingRow(symbol: "checkmark.seal.fill", tint: .green, title: "Test connection", subtitle: status) {
                    Button(ai.testing ? "Testing…" : "Test") { ai.test() }.disabled(ai.testing)
                }
            }

            DisclosureGroup("What your model receives") {
                Text("Prompts can include your pet’s name and mood, time of day, the app playing audio, daily counts, memories and requests you type in Ask. Keystrokes, screen contents and calendar events stay private. Choose a local server to keep prompts on your Mac.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 4)
        }
    }

    private var abilities: some View {
        CardSection(title: "Pet abilities",
                    footer: "If the server is off or slow, the pet carries on with its built-in lines and behaviour. Reminders and calendar alerts always use their exact wording.") {
            ToggleRow(symbol: "text.bubble.fill", tint: .green, title: "Fresh lines",
                      subtitle: "Writes new things to say for every moment, in your pet's own voice. \(ai.generatedLineCount) written so far",
                      isOn: $settings.aiDialogue)
            RowDivider()
            ToggleRow(symbol: "eye.fill", tint: .teal, title: "Remarks about what's going on",
                      subtitle: "Music starting, coming back, the time of day, the battery, a busy Mac", isOn: $settings.aiReactions)
            RowDivider()
            ToggleRow(symbol: "brain.head.profile", tint: .pink, title: "Decide what to do",
                      subtitle: "Every few minutes the model picks the next move; the rest of the time the pet follows its instincts",
                      isOn: $settings.aiBrain)
            RowDivider()
            ToggleRow(symbol: "bubble.left.and.bubble.right.fill", tint: .orange, title: "Two pets talk to each other",
                      subtitle: "They chat when they meet: about you, your day, what's on, or pet life", isOn: $settings.aiBanter)
            RowDivider()
            ToggleRow(symbol: "keyboard", tint: .blue, title: "Ask your pet",
                      subtitle: "Type a request from the menu: \u{201C}dance\u{201D}, \u{201C}remind me to drink water every 30 minutes\u{201D}, \u{201C}25 minute focus\u{201D}",
                      isOn: $settings.aiCommands)
            RowDivider()
            ToggleRow(symbol: "book.closed.fill", tint: .brown, title: "Memory and diary",
                      subtitle: "Remembers a few things about you and writes a diary entry for each day", isOn: $settings.aiMemory)
            RowDivider()
            SettingRow(symbol: "arrow.clockwise", tint: .gray, title: "Written lines",
                       subtitle: "Throw them away after changing model; new ones are written as needed") {
                Button("Start over") { ai.clearLines() }.disabled(ai.generatedLineCount == 0)
            }
        }
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardSection(title: "Diary",
                        footer: "Yesterday's entry is written the next time you open Mochi.") {
                SettingRow(symbol: "pencil.line", tint: .brown, title: "Today's entry",
                           subtitle: ai.writingDiary ? "Writing…" : "Write it now from today so far") {
                    Button("Write") { ai.writeDiary(DailyLog.shared.current) }
                        .disabled(ai.writingDiary || !ai.on(.memory))
                }
                ForEach(memory.diary.prefix(7)) { entry in
                    RowDivider()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.day).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(entry.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .textSelection(.enabled)
                }
            }

            CardSection(title: "What \(settings.species.name) remembers about you",
                        footer: "Ask your pet to remember something (\u{201C}remember that I like lo-fi\u{201D}); it also picks up a habit now and then when it writes its diary. Kept on this Mac in Application Support/Mochi.") {
                if memory.facts.isEmpty {
                    Text("Nothing yet.").font(.callout).foregroundStyle(.secondary).padding(14)
                }
                ForEach(Array(memory.facts.enumerated()), id: \.offset) { i, fact in
                    if i > 0 { RowDivider() }
                    HStack(spacing: 10) {
                        Text(fact).font(.callout).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button { memory.forget(at: i) } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .accessibilityLabel("Forget this")
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                }
                if !memory.facts.isEmpty || !memory.diary.isEmpty {
                    RowDivider()
                    SettingRow(symbol: "trash.fill", tint: .red, title: "Forget everything",
                               subtitle: "Clears the memories and the diary") {
                        Button("Forget") { memory.forgetEverything() }
                    }
                }
            }
        }
    }
}

#endif
