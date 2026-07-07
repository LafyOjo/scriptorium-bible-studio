import CoreData
import SwiftUI
import UIKit

struct EditorView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var chapter: SBChapter
    @ObservedObject var book: SBBook
    let settings: SBAppSettings?
    @Binding var selectedText: String

    @StateObject private var richTextContext = RichTextContext()
    @StateObject private var speechReader = SpeechReader()

    @State private var attributedText = NSAttributedString()
    @State private var mode: EditorMode = .write
    @State private var nextVerse = 1
    @State private var saveTask: Task<Void, Never>?
    @State private var saveState: SaveState = .saved
    @State private var titleText = ""
    @State private var status: ChapterStatus = .notStarted
    @State private var showFontSheet = false
    @State private var selectedColor = UIColor.label

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()
            if mode == .write {
                formattingToolbar
                Divider()
            }

            Group {
                if mode == .write {
                    RichTextEditor(
                        text: $attributedText,
                        selectedText: $selectedText,
                        context: richTextContext,
                        settings: settings,
                        onTextChange: scheduleSave
                    )
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                } else {
                    ScrollView {
                        AttributedPreview(text: attributedText, isScrollEnabled: false)
                            .padding(28)
                            .frame(maxWidth: 760)
                    }
                }
            }
        }
        .navigationTitle("\(book.name) \(chapter.number)")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ExportMenuButton(chapter: chapter, book: book)
                Button {
                    showFontSheet = true
                } label: {
                    Label("Fonts", systemImage: "textformat.size")
                }
            }
        }
        .sheet(isPresented: $showFontSheet) {
            FontControlsSheet(settings: settings, richTextContext: richTextContext)
        }
        .onAppear(perform: loadChapter)
        .onDisappear {
            saveTask?.cancel()
            persist(attributedText)
            speechReader.stop()
        }
        .onChange(of: chapter.objectID) { _, _ in
            loadChapter()
        }
        .onChange(of: titleText) { _, value in
            guard value != chapter.title else { return }
            chapter.title = value
            chapter.updatedAt = Date()
            ScriptoriumActions.save(viewContext)
        }
        .onChange(of: status) { _, value in
            guard value.rawValue != chapter.status else { return }
            chapter.status = value.rawValue
            chapter.updatedAt = Date()
            ScriptoriumActions.save(viewContext)
        }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(book.name.uppercased()) / CHAPTER \(chapter.number)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ScriptoriumPalette.rose)
                        .tracking(1.2)

                    TextField("Chapter title", text: $titleText)
                        .font(.system(.largeTitle, design: .serif).weight(.semibold))
                        .textFieldStyle(.plain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Picker("Mode", selection: $mode) {
                        ForEach(EditorMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)

                    HStack(spacing: 8) {
                        StatusPill(status: status)
                        Picker("Status", selection: $status) {
                            ForEach(ChapterStatus.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            HStack(spacing: 12) {
                readAloudControls

                Spacer()

                Label("\(wordCount(attributedText.string)) words", systemImage: "text.word.spacing")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(saveState.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(saveState.tint)
            }
        }
        .padding(20)
        .background(.thinMaterial)
    }

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ToolbarIcon("Bold", systemImage: "bold") { richTextContext.toggleBold() }
                ToolbarIcon("Italic", systemImage: "italic") { richTextContext.toggleItalic() }
                ToolbarIcon("Underline", systemImage: "underline") { richTextContext.toggleUnderline() }
                ToolbarIcon("Heading", systemImage: "textformat.size.larger") { richTextContext.applyHeading() }
                ToolbarIcon("Quote", systemImage: "quote.opening") { richTextContext.applyQuote() }
                ToolbarIcon("Uppercase", systemImage: "character.cursor.ibeam") { richTextContext.uppercaseSelection() }
                ToolbarIcon("Small Caps", systemImage: "textformat.alt") { richTextContext.applySmallCaps() }

                Divider().frame(height: 24)

                Button {
                    richTextContext.insertVerseNumber(nextVerse)
                    nextVerse += 1
                } label: {
                    Label("v\(nextVerse)", systemImage: "number")
                }
                .buttonStyle(.bordered)

                ToolbarIcon("Section Title", systemImage: "text.aligncenter") { richTextContext.insertSectionTitle() }
                ToolbarIcon("Footnote", systemImage: "asterisk") { richTextContext.insertFootnoteMarker() }

                Divider().frame(height: 24)

                Menu {
                    ForEach(HighlightTheme.allCases) { theme in
                        Button {
                            richTextContext.applyHighlight(theme)
                            ScriptoriumActions.recordHighlightTheme(theme, in: chapter, context: viewContext)
                        } label: {
                            Label(theme.label, systemImage: "highlighter")
                        }
                    }
                } label: {
                    Label("Highlight", systemImage: "highlighter")
                }
                .buttonStyle(.bordered)

                Menu {
                    colorButton("Ink", color: .label)
                    colorButton("Oxblood", color: UIColor(red: 0.60, green: 0.16, blue: 0.18, alpha: 1))
                    colorButton("Gold", color: UIColor(red: 0.72, green: 0.51, blue: 0.18, alpha: 1))
                    colorButton("Teal", color: UIColor(red: 0.10, green: 0.55, blue: 0.47, alpha: 1))
                    colorButton("Indigo", color: UIColor(red: 0.34, green: 0.43, blue: 0.88, alpha: 1))
                    colorButton("Rose", color: UIColor(red: 0.82, green: 0.26, blue: 0.39, alpha: 1))
                } label: {
                    Label("Colour", systemImage: "paintpalette")
                }
                .buttonStyle(.bordered)

                if let settings {
                    Divider().frame(height: 24)
                    Menu {
                        ForEach(FontOption.all) { option in
                            Button(option.label) {
                                richTextContext.applyFont(name: option.id)
                            }
                        }
                    } label: {
                        Label(fontLabel(settings.fontName), systemImage: "textformat")
                    }
                    .buttonStyle(.bordered)

                    Stepper(value: Binding(
                        get: { settings.fontSize },
                        set: {
                            settings.fontSize = $0
                            ScriptoriumActions.save(viewContext)
                            richTextContext.applyFontSize(CGFloat($0))
                        }
                    ), in: 12...34, step: 1) {
                        Text("\(Int(settings.fontSize)) pt")
                            .font(.caption.weight(.medium))
                    }
                    .frame(width: 130)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var readAloudControls: some View {
        HStack(spacing: 8) {
            switch speechReader.state {
            case .stopped:
                Button {
                    speechReader.start(text: attributedText.string)
                } label: {
                    Label("Read aloud", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
            case .speaking:
                Button {
                    speechReader.pause()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(ScriptoriumPalette.teal)

                Button {
                    speechReader.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            case .paused:
                Button {
                    speechReader.resume()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(ScriptoriumPalette.teal)

                Button {
                    speechReader.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.caption.weight(.medium))
    }

    private func ToolbarIcon(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.bordered)
        .help(title)
    }

    private func colorButton(_ title: String, color: UIColor) -> some View {
        Button {
            selectedColor = color
            richTextContext.applyForegroundColor(color)
        } label: {
            Label(title, systemImage: "circle.fill")
        }
    }

    private func loadChapter() {
        titleText = chapter.title
        status = chapter.statusValue
        attributedText = AttributedContent.fromRTFData(chapter.contentData, settings: settings)
        nextVerse = nextVerseNumber(in: attributedText.string)
        saveState = .saved
    }

    private func scheduleSave(_ text: NSAttributedString) {
        attributedText = text
        saveState = .saving
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            persist(text)
            saveState = .saved
        }
    }

    private func persist(_ text: NSAttributedString) {
        chapter.contentData = AttributedContent.rtfData(from: text)
        chapter.plainText = text.string
        chapter.updatedAt = Date()
        ScriptoriumActions.save(viewContext)
    }

    private func wordCount(_ string: String) -> Int {
        string.split { $0.isWhitespace || $0.isNewline }.count
    }

    private func nextVerseNumber(in text: String) -> Int {
        let pattern = #"(?m)^\s*(\d{1,3})\s"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 1 }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        let values = matches.compactMap { match -> Int? in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return Int(text[range])
        }
        return (values.max() ?? 0) + 1
    }

    private func fontLabel(_ fontName: String) -> String {
        FontOption.all.first { $0.id == fontName }?.label ?? "Font"
    }
}

private enum SaveState {
    case saved
    case saving

    var label: String {
        switch self {
        case .saved: return "Saved"
        case .saving: return "Saving..."
        }
    }

    var tint: Color {
        switch self {
        case .saved: return ScriptoriumPalette.teal
        case .saving: return ScriptoriumPalette.amber
        }
    }
}

private struct FontControlsSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let settings: SBAppSettings?
    let richTextContext: RichTextContext

    var body: some View {
        NavigationStack {
            if let settings {
                Form {
                    Section("Default Editor Font") {
                        Picker("Typeface", selection: Binding(
                            get: { settings.fontName },
                            set: {
                                settings.fontName = $0
                                ScriptoriumActions.save(viewContext)
                                richTextContext.applyFont(name: $0)
                            }
                        )) {
                            ForEach(FontOption.all) { option in
                                Text(option.label).tag(option.id)
                            }
                        }

                        VStack(alignment: .leading) {
                            Text("Size: \(Int(settings.fontSize)) pt")
                            Slider(value: Binding(
                                get: { settings.fontSize },
                                set: {
                                    settings.fontSize = $0
                                    ScriptoriumActions.save(viewContext)
                                    richTextContext.applyFontSize(CGFloat($0))
                                }
                            ), in: 12...34, step: 1)
                        }

                        VStack(alignment: .leading) {
                            Text("Line spacing: \(Int(settings.lineSpacing))")
                            Slider(value: Binding(
                                get: { settings.lineSpacing },
                                set: {
                                    settings.lineSpacing = $0
                                    ScriptoriumActions.save(viewContext)
                                }
                            ), in: 0...14, step: 1)
                        }
                    }

                    Section("Default Style") {
                        Toggle("Bold", isOn: Binding(
                            get: { settings.defaultBold },
                            set: { settings.defaultBold = $0; ScriptoriumActions.save(viewContext) }
                        ))
                        Toggle("Italic", isOn: Binding(
                            get: { settings.defaultItalic },
                            set: { settings.defaultItalic = $0; ScriptoriumActions.save(viewContext) }
                        ))
                        Toggle("Underline", isOn: Binding(
                            get: { settings.defaultUnderline },
                            set: { settings.defaultUnderline = $0; ScriptoriumActions.save(viewContext) }
                        ))
                    }

                    Section("Preview") {
                        Text("In the beginning was the Word.")
                            .font(.custom(settings.fontName == "system-serif" ? "Times New Roman" : settings.fontName, size: CGFloat(settings.fontSize)))
                            .conditionalBold(settings.defaultBold)
                            .conditionalItalic(settings.defaultItalic)
                            .underline(settings.defaultUnderline)
                    }
                }
                .navigationTitle("Fonts")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            } else {
                EmptyStateView(title: "Settings Unavailable", message: "Restart the app to regenerate default settings.", systemImage: "exclamationmark.triangle")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private extension View {
    @ViewBuilder
    func conditionalBold(_ enabled: Bool) -> some View {
        if enabled {
            bold()
        } else {
            self
        }
    }

    @ViewBuilder
    func conditionalItalic(_ enabled: Bool) -> some View {
        if enabled {
            italic()
        } else {
            self
        }
    }
}
