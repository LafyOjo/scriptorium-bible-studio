import CoreData
import SwiftUI
import UIKit

struct EditorView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var chapter: SBChapter
    @ObservedObject var book: SBBook
    let settings: SBAppSettings?
    @Binding var selectedText: String

    @StateObject private var richTextContext = RichTextContext()
    @StateObject private var speechReader = SpeechReader()
    @StateObject private var draftBuffer = EditorDraftBuffer()

    @State private var attributedText = NSAttributedString()
    @State private var mode: EditorMode = .write
    @State private var nextVerse = 1
    @State private var saveTask: Task<Void, Never>?
    @State private var saveState: SaveState = .saved
    @State private var titleText = ""
    @State private var status: ChapterStatus = .notStarted
    @State private var showFontSheet = false
    @State private var showMoreToolsSheet = false
    @State private var selectedColor = SBTheme.uiInk
    @State private var readerTheme: ReaderTheme = .parchment
    @State private var wordCountValue = 0
    @State private var saveError: EditorSaveError?

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()
            if let saveError {
                SaveErrorBanner(error: saveError) {
                    persistNow(force: true)
                } dismiss: {
                    self.saveError = nil
                }
                Divider()
            }
            if mode == .write && !isCompact {
                formattingToolbar
                Divider()
            } else if mode == .read && !isCompact {
                readerControlStrip
                Divider()
            }

            Group {
                if mode == .write {
                    RichTextEditor(
                        text: $attributedText,
                        selectedText: $selectedText,
                        context: richTextContext,
                        settings: settings,
                        documentID: chapter.id,
                        onTextChange: scheduleSave
                    ) { color in
                        selectedColor = color ?? SBTheme.uiInk
                    }
                    .padding(.horizontal, isCompact ? 14 : 22)
                    .padding(.vertical, isCompact ? 12 : 18)
                } else {
                    ScrollView {
                        ParchmentPanel(padding: isCompact ? 20 : 30) {
                            AttributedPreview(text: readerPreviewText, isScrollEnabled: false)
                                .frame(maxWidth: 760)
                        }
                        .background(readerTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(isCompact ? 14 : 28)
                    }
                    .background(readerTheme.background.opacity(0.5))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if mode == .write && isCompact {
                compactFormattingBar
            } else if mode == .read && isCompact {
                readerControlStrip
            }
        }
        .navigationTitle("\(book.name) \(chapter.number)")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isCompact {
                    DocumentMenuButton(
                        chapter: chapter,
                        book: book,
                        save: { persistNow(force: true) },
                        showFonts: { showFontSheet = true }
                    )
                } else {
                    Button {
                        persistNow(force: true)
                    } label: {
                        Label("Save", systemImage: "tray.and.arrow.down")
                    }
                    PlainTextShareButton(chapter: chapter, book: book)
                    ExportMenuButton(chapter: chapter, book: book)
                    Button {
                        showFontSheet = true
                    } label: {
                        Label("Fonts", systemImage: "textformat.size")
                    }
                }
            }
        }
        .sheet(isPresented: $showFontSheet) {
            FontControlsSheet(settings: settings, richTextContext: richTextContext)
        }
        .sheet(isPresented: $showMoreToolsSheet) {
            MoreToolsSheet(
                settings: settings,
                richTextContext: richTextContext,
                nextVerse: nextVerse,
                insertVerse: insertNextVerseNumber
            )
        }
        .onAppear(perform: loadChapter)
        .onDisappear {
            saveTask?.cancel()
            persistSynchronouslyOnDisappear()
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
        .onChange(of: readerTheme) { _, value in
            settings?.readerTheme = value.rawValue
            settings?.theme = value.rawValue
            settings?.updatedAt = Date()
            ScriptoriumActions.save(viewContext)
        }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    titleBlock
                    Spacer(minLength: 12)
                    chapterControls(alignment: .trailing, frameAlignment: .trailing, maxWidth: 260)
                }

                VStack(alignment: .leading, spacing: 12) {
                    titleBlock
                    chapterControls(alignment: .leading, frameAlignment: .leading, maxWidth: .infinity)
                }
            }

            if isCompact {
                writingMeta
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        readAloudControls
                        Spacer(minLength: 12)
                        writingMeta
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        readAloudControls
                        writingMeta
                    }
                }
            }
        }
        .padding(isCompact ? 14 : 20)
        .background(.thinMaterial)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(book.name.uppercased()) / CHAPTER \(chapter.number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ScriptoriumPalette.rose)
                .tracking(1.2)

            TextField("Chapter title", text: $titleText)
                .font(SBTheme.body(isCompact ? 28 : 36, weight: .semibold))
                .textFieldStyle(.plain)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chapterControls(
        alignment: HorizontalAlignment,
        frameAlignment: Alignment,
        maxWidth: CGFloat?
    ) -> some View {
        VStack(alignment: alignment, spacing: 10) {
            Picker("Mode", selection: $mode) {
                ForEach(EditorMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)

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
        .frame(maxWidth: maxWidth, alignment: frameAlignment)
    }

    private var writingMeta: some View {
        HStack(spacing: 12) {
            Label("\(wordCountValue) words", systemImage: "text.word.spacing")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(saveState.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(saveState.tint)
        }
    }

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ToolbarIcon("Undo", systemImage: "arrow.uturn.backward") { richTextContext.undo() }
                ToolbarIcon("Redo", systemImage: "arrow.uturn.forward") { richTextContext.redo() }

                Divider().frame(height: 24)

                ToolbarIcon("Bold", systemImage: "bold") { richTextContext.toggleBold() }
                ToolbarIcon("Italic", systemImage: "italic") { richTextContext.toggleItalic() }
                ToolbarIcon("Underline", systemImage: "underline") { richTextContext.toggleUnderline() }
                ToolbarIcon("Strike", systemImage: "strikethrough") { richTextContext.toggleStrikethrough() }
                ToolbarIcon("Superscript", systemImage: "textformat.superscript") { richTextContext.toggleSuperscript() }
                ToolbarIcon("Subscript", systemImage: "textformat.subscript") { richTextContext.toggleSubscript() }

                Menu {
                    Button("Heading 1") { richTextContext.applyHeading(level: 1) }
                    Button("Heading 2") { richTextContext.applyHeading(level: 2) }
                    Button("Heading 3") { richTextContext.applyHeading(level: 3) }
                    Button("Paragraph") { richTextContext.applyParagraph() }
                    Button("Preformatted") { richTextContext.applyPreformatted() }
                } label: {
                    Label("Styles", systemImage: "textformat.size.larger")
                }
                .buttonStyle(.bordered)

                ToolbarIcon("Outdent", systemImage: "decrease.indent") { richTextContext.adjustIndent(by: -18) }
                ToolbarIcon("Indent", systemImage: "increase.indent") { richTextContext.adjustIndent(by: 18) }
                ToolbarIcon("Quote", systemImage: "quote.opening") { richTextContext.applyQuote() }
                ToolbarIcon("Uppercase", systemImage: "character.cursor.ibeam") { richTextContext.uppercaseSelection() }
                ToolbarIcon("Small Caps", systemImage: "textformat.alt") { richTextContext.applySmallCaps() }
                ToolbarIcon("Clear Formatting", systemImage: "eraser") { richTextContext.clearFormatting() }

                Menu {
                    Button { richTextContext.applyAlignment(.left) } label: { Label("Left", systemImage: "text.alignleft") }
                    Button { richTextContext.applyAlignment(.center) } label: { Label("Center", systemImage: "text.aligncenter") }
                    Button { richTextContext.applyAlignment(.right) } label: { Label("Right", systemImage: "text.alignright") }
                    Button { richTextContext.applyAlignment(.justified) } label: { Label("Justify", systemImage: "text.justify") }
                } label: {
                    Label("Align", systemImage: "text.alignleft")
                }
                .buttonStyle(.bordered)

                Menu {
                    Button { richTextContext.toggleList(ordered: false) } label: { Label("Bulleted List", systemImage: "list.bullet") }
                    Button { richTextContext.toggleList(ordered: true) } label: { Label("Numbered List", systemImage: "list.number") }
                } label: {
                    Label("Lists", systemImage: "list.bullet")
                }
                .buttonStyle(.bordered)

                Divider().frame(height: 24)

                Button {
                    insertNextVerseNumber()
                } label: {
                    Label("v\(nextVerse)", systemImage: "number")
                }
                .buttonStyle(.bordered)

                ToolbarIcon("Section Title", systemImage: "text.aligncenter") { richTextContext.insertSectionTitle() }
                ToolbarIcon("Footnote", systemImage: "asterisk") { richTextContext.insertFootnoteMarker() }
                ToolbarIcon("Link", systemImage: "link") { richTextContext.insertLinkPlaceholder() }

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
                    ForEach(TextColorOption.all) { option in
                        colorButton(option)
                    }
                    Divider()
                    Button {
                        selectedColor = SBTheme.uiInk
                        richTextContext.resetForegroundColor()
                    } label: {
                        Label("Reset Text Colour", systemImage: "xmark.circle")
                    }
                    .accessibilityLabel("Reset text colour to default ink")
                } label: {
                    ColourMenuLabel(color: selectedColor)
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

                    Menu {
                        ForEach(FontSizeOption.all) { option in
                            Button(option.label) {
                                settings.fontSize = option.size
                                settings.readerFontSize = option.size
                                settings.updatedAt = Date()
                                ScriptoriumActions.save(viewContext)
                                richTextContext.applyFontSize(CGFloat(option.size))
                            }
                        }
                    } label: {
                        Label("Size", systemImage: "textformat.size")
                    }
                    .buttonStyle(.bordered)

                    Stepper(value: Binding(
                        get: { settings.fontSize },
                        set: {
                            settings.fontSize = $0
                            settings.readerFontSize = $0
                            settings.updatedAt = Date()
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

    private var compactFormattingBar: some View {
        VStack(spacing: 0) {
            GoldDivider()
                .padding(.top, 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                CompactToolButton(title: "Undo", systemImage: "arrow.uturn.backward") {
                    richTextContext.undo()
                }
                CompactToolButton(title: "Redo", systemImage: "arrow.uturn.forward") {
                    richTextContext.redo()
                }
                CompactToolButton(title: "Bold", systemImage: "bold") {
                    richTextContext.toggleBold()
                }
                CompactToolButton(title: "Italic", systemImage: "italic") {
                    richTextContext.toggleItalic()
                }
                CompactToolButton(title: "Underline", systemImage: "underline") {
                    richTextContext.toggleUnderline()
                }

                Menu {
                    ForEach(TextColorOption.all) { option in
                        colorButton(option)
                    }
                    Divider()
                    Button {
                        selectedColor = SBTheme.uiInk
                        richTextContext.resetForegroundColor()
                    } label: {
                        Label("Reset Text Colour", systemImage: "xmark.circle")
                    }
                    .accessibilityLabel("Reset text colour to default ink")
                } label: {
                    CompactToolLabel(
                        title: "Colour",
                        subtitle: selectedColorLabel,
                        systemImage: "paintpalette",
                        swatch: Color(uiColor: selectedColor)
                    )
                }
                .accessibilityLabel("Colour. Current colour \(selectedColorLabel)")

                Menu {
                    ForEach(HighlightTheme.allCases) { theme in
                        Button {
                            richTextContext.applyHighlight(theme)
                            ScriptoriumActions.recordHighlightTheme(theme, in: chapter, context: viewContext)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(theme.color)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(SBTheme.border, lineWidth: 1))
                                Text(theme.label)
                            }
                        }
                        .accessibilityLabel("Highlight \(theme.label)")
                    }
                } label: {
                    CompactToolLabel(title: "Highlight", subtitle: "Themes", systemImage: "highlighter")
                }
                .accessibilityLabel("Highlight text")

                CompactToolButton(title: "More", systemImage: "ellipsis.circle") {
                    showMoreToolsSheet = true
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private var readerControlStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                readAloudControls

                Menu {
                    ForEach(ReaderTheme.allCases) { theme in
                        Button {
                            readerTheme = theme
                        } label: {
                            Label(theme.label, systemImage: theme.systemImage)
                        }
                    }
                } label: {
                    Label(readerTheme.label, systemImage: readerTheme.systemImage)
                }
                .buttonStyle(.bordered)

                if let settings {
                    Stepper(value: Binding(
                        get: { settings.readerFontSize == 0 ? settings.fontSize : settings.readerFontSize },
                        set: {
                            settings.readerFontSize = $0
                            settings.updatedAt = Date()
                            ScriptoriumActions.save(viewContext)
                        }
                    ), in: 14...34, step: 1) {
                        Label("\(Int(settings.readerFontSize == 0 ? settings.fontSize : settings.readerFontSize)) pt", systemImage: "textformat.size")
                            .font(.caption.weight(.medium))
                    }
                    .frame(width: 150)
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
                    speechReader.start(
                        text: draftBuffer.currentText(fallback: attributedText).string,
                        rate: Float(settings?.readAloudRate ?? 0.48),
                        voiceIdentifier: settings?.voiceIdentifier
                    )
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

    private func colorButton(_ option: TextColorOption) -> some View {
        Button {
            selectedColor = option.uiColor
            richTextContext.applyForegroundColor(option.uiColor)
        } label: {
            HStack {
                Circle()
                    .fill(Color(uiColor: option.uiColor))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(SBTheme.border, lineWidth: 1))
                Text(option.label)
                if option.uiColor.isVisuallyEqual(to: selectedColor) {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
        .accessibilityLabel("Text colour \(option.label)")
    }

    private func loadChapter() {
        titleText = chapter.title
        status = chapter.statusValue
        attributedText = AttributedContent.fromRTFData(chapter.attributedData ?? chapter.contentData, settings: settings)
        draftBuffer.load(attributedText)
        wordCountValue = wordCount(attributedText.string)
        nextVerse = nextVerseNumber(in: attributedText.string)
        readerTheme = ReaderTheme(rawValue: settings?.readerTheme ?? settings?.theme ?? "") ?? .parchment
        saveState = .saved
        saveError = nil
    }

    private func scheduleSave(_ text: NSAttributedString) {
        draftBuffer.update(text)
        wordCountValue = wordCount(text.string)
        guard settings?.autosaveEnabled != false else {
            saveTask?.cancel()
            saveState = .manual
            return
        }
        saveState = .saving
        saveTask?.cancel()
        let snapshot = text.copy() as? NSAttributedString ?? NSAttributedString(attributedString: text)
        let delay = snapshot.length > 25_000 ? 1_500 : 1_100
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            await persistSnapshot(snapshot, force: false)
        }
    }

    private func persistNow(force: Bool) {
        saveTask?.cancel()
        let snapshot = draftBuffer.currentText(fallback: attributedText)
        saveState = .saving
        Task { @MainActor in
            await persistSnapshot(snapshot, force: force)
        }
    }

    private func persistSnapshot(_ text: NSAttributedString, force: Bool) async {
        guard force || draftBuffer.hasPendingChanges else {
            saveState = .saved
            return
        }

        let plainText = text.string
        let data = await Task.detached(priority: .utility) {
            AttributedContent.rtfData(from: text)
        }.value

        guard !Task.isCancelled else { return }

        // Only overwrite the persisted blob when encoding actually succeeded.
        // Otherwise a transient encoder failure would wipe the chapter body.
        if let data {
            chapter.contentData = data
            chapter.attributedData = data
        }
        chapter.plainText = plainText
        chapter.updatedAt = Date()

        do {
            try ScriptoriumActions.saveThrowing(viewContext)
            attributedText = text
            draftBuffer.markPersisted(text)
            wordCountValue = wordCount(plainText)
            saveState = .saved
            saveError = nil
        } catch {
            saveState = .failed
            saveError = EditorSaveError(message: error.localizedDescription)
        }
    }

    private func persistSynchronouslyOnDisappear() {
        let snapshot = draftBuffer.currentText(fallback: attributedText)
        guard draftBuffer.hasPendingChanges else { return }
        if let data = AttributedContent.rtfData(from: snapshot) {
            chapter.contentData = data
            chapter.attributedData = data
        }
        chapter.plainText = snapshot.string
        chapter.updatedAt = Date()
        do {
            try ScriptoriumActions.saveThrowing(viewContext)
            draftBuffer.markPersisted(snapshot)
            saveState = .saved
            saveError = nil
        } catch {
            saveState = .failed
            saveError = EditorSaveError(message: error.localizedDescription)
        }
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

    private var selectedColorLabel: String {
        TextColorOption.all.first { $0.uiColor.isVisuallyEqual(to: selectedColor) }?.label ?? "Custom"
    }

    private func insertNextVerseNumber() {
        richTextContext.insertVerseNumber(nextVerse)
        nextVerse += 1
    }

    private var readerPreviewText: NSAttributedString {
        let preview = NSMutableAttributedString(attributedString: draftBuffer.currentText(fallback: attributedText))
        let fullRange = NSRange(location: 0, length: preview.length)
        guard fullRange.length > 0 else { return preview }

        let readerSize = CGFloat(settings?.readerFontSize ?? settings?.fontSize ?? 19)
        preview.enumerateAttributes(in: fullRange) { attributes, range, _ in
            let color = attributes[.foregroundColor] as? UIColor
            let role = attributes[.scriptoriumForegroundColorRole]
            if AttributedContent.shouldPreserveForegroundColor(color, role: role), let color {
                preview.addAttribute(
                    .foregroundColor,
                    value: AttributedContent.readerColor(color, onDarkBackground: readerTheme == .dark),
                    range: range
                )
            } else {
                preview.addAttribute(.foregroundColor, value: readerTheme.textColor, range: range)
            }
        }
        preview.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let font = (value as? UIFont) ?? SBTheme.bodyUIFont(size: readerSize)
            preview.addAttribute(.font, value: font.withSize(readerSize), range: range)
        }

        if let currentRange = speechReader.currentRange,
           currentRange.location + currentRange.length <= preview.length {
            preview.addAttribute(
                .backgroundColor,
                value: SBTheme.uiGoldSoft.withAlphaComponent(readerTheme == .dark ? 0.34 : 0.58),
                range: currentRange
            )
        }

        return preview
    }
}

private enum ReaderTheme: String, CaseIterable, Identifiable {
    case parchment
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .parchment: return "Parchment"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .parchment: return "book.closed"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var background: Color {
        switch self {
        case .parchment: return SBTheme.parchment
        case .light: return SBTheme.ivory
        case .dark: return Color(hex: 0x1D1711)
        }
    }

    var textColor: UIColor {
        switch self {
        case .parchment, .light: return SBTheme.uiInk
        case .dark: return UIColor(hex: 0xF8EFD8)
        }
    }
}

private struct FontSizeOption: Identifiable {
    let id: String
    let label: String
    let size: Double

    static let all: [FontSizeOption] = [
        FontSizeOption(id: "xs", label: "XS - 14 pt", size: 14),
        FontSizeOption(id: "s", label: "S - 16 pt", size: 16),
        FontSizeOption(id: "m", label: "M - 19 pt", size: 19),
        FontSizeOption(id: "l", label: "L - 22 pt", size: 22),
        FontSizeOption(id: "xl", label: "XL - 26 pt", size: 26),
        FontSizeOption(id: "2xl", label: "2XL - 30 pt", size: 30),
    ]
}

private struct TextColorOption: Identifiable {
    let id: String
    let label: String
    let uiColor: UIColor

    static let all: [TextColorOption] = [
        TextColorOption(id: "ink", label: "Ink", uiColor: SBTheme.uiInk),
        TextColorOption(id: "primary", label: "Deep Brown", uiColor: SBTheme.uiPrimary),
        TextColorOption(id: "gold", label: "Gold", uiColor: SBTheme.uiGold),
        TextColorOption(id: "crimson", label: "Crimson", uiColor: SBTheme.uiCrimson),
        TextColorOption(id: "mercy", label: "Mercy Green", uiColor: UIColor(hex: 0x2F5230)),
        TextColorOption(id: "prophecy", label: "Prophecy Blue", uiColor: UIColor(hex: 0x1F3B6B)),
        TextColorOption(id: "royal", label: "Royal Purple", uiColor: UIColor(hex: 0x5C2A72)),
        TextColorOption(id: "muted", label: "Muted", uiColor: SBTheme.uiMutedForeground),
    ]
}

private struct ColourMenuLabel: View {
    let color: UIColor

    var body: some View {
        Label {
            Text("Colour")
        } icon: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "paintpalette")
                Circle()
                    .fill(Color(uiColor: color))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(.white, lineWidth: 1))
                    .offset(x: 4, y: 4)
            }
        }
        .accessibilityLabel("Text colour. Current colour selected.")
    }
}

private struct CompactToolButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CompactToolLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}

private struct CompactToolLabel: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var swatch: Color?

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                if let swatch {
                    Circle()
                        .fill(swatch)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(.white, lineWidth: 1))
                        .offset(x: 6, y: 4)
                }
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(SBTheme.mutedForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .foregroundStyle(SBTheme.primary)
        .frame(maxWidth: .infinity)
        .frame(minHeight: subtitle == nil ? 50 : 58)
        .padding(.horizontal, 4)
        .background(SBTheme.ivory.opacity(0.86), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(SBTheme.border, lineWidth: 1)
        )
    }
}

private struct DocumentMenuButton: View {
    let chapter: SBChapter
    let book: SBBook?
    let save: () -> Void
    let showFonts: () -> Void

    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    var body: some View {
        Menu {
            Section("Document") {
                Button(action: save) {
                    Label("Save Now", systemImage: "tray.and.arrow.down")
                }
                Button(action: showFonts) {
                    Label("Fonts And Sizes", systemImage: "textformat.size")
                }
            }

            Section("Share") {
                Button {
                    export(.text)
                } label: {
                    Label("Share Plain Text", systemImage: "doc.plaintext")
                }
            }

            Section("Export") {
                ForEach(ExportKind.allCases) { kind in
                    Button {
                        export(kind)
                    } label: {
                        Label("Export \(kind.label)", systemImage: kind.systemImage)
                    }
                }
            }
        } label: {
            Label("Document", systemImage: "doc.text")
        }
        .accessibilityLabel("Document menu. Save, share, export and fonts.")
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert("Document action failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    private func export(_ kind: ExportKind) {
        do {
            shareItem = ShareItem(url: try ExportService.chapterURL(chapter: chapter, book: book, kind: kind))
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct MoreToolsSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let settings: SBAppSettings?
    let richTextContext: RichTextContext
    let nextVerse: Int
    let insertVerse: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MoreToolsSection(title: "Text Style", systemImage: "textformat") {
                        MoreToolButton("Strikethrough", systemImage: "strikethrough") { richTextContext.toggleStrikethrough() }
                        MoreToolButton("Superscript", systemImage: "textformat.superscript") { richTextContext.toggleSuperscript() }
                        MoreToolButton("Subscript", systemImage: "textformat.subscript") { richTextContext.toggleSubscript() }
                        MoreToolButton("Uppercase", systemImage: "character.cursor.ibeam") { richTextContext.uppercaseSelection() }
                        MoreToolButton("Small Caps", systemImage: "textformat.alt") { richTextContext.applySmallCaps() }
                        MoreToolButton("Clear Formatting", systemImage: "eraser") { richTextContext.clearFormatting() }
                    }

                    MoreToolsSection(title: "Scripture Structure", systemImage: "text.book.closed") {
                        MoreToolButton("Heading 1", systemImage: "textformat.size.larger") { richTextContext.applyHeading(level: 1) }
                        MoreToolButton("Heading 2", systemImage: "textformat.size") { richTextContext.applyHeading(level: 2) }
                        MoreToolButton("Heading 3", systemImage: "textformat") { richTextContext.applyHeading(level: 3) }
                        MoreToolButton("Paragraph", systemImage: "paragraphsign") { richTextContext.applyParagraph() }
                        MoreToolButton("Preformatted", systemImage: "curlybraces") { richTextContext.applyPreformatted() }
                        MoreToolButton("Verse \(nextVerse)", systemImage: "number") { insertVerse() }
                        MoreToolButton("Section Title", systemImage: "text.aligncenter") { richTextContext.insertSectionTitle() }
                        MoreToolButton("Footnote", systemImage: "asterisk") { richTextContext.insertFootnoteMarker() }
                        MoreToolButton("Link", systemImage: "link") { richTextContext.insertLinkPlaceholder() }
                    }

                    MoreToolsSection(title: "Paragraph Layout", systemImage: "increase.indent") {
                        MoreToolButton("Quote", systemImage: "quote.opening") { richTextContext.applyQuote() }
                        MoreToolButton("Indent", systemImage: "increase.indent") { richTextContext.adjustIndent(by: 18) }
                        MoreToolButton("Outdent", systemImage: "decrease.indent") { richTextContext.adjustIndent(by: -18) }
                        MoreToolButton("Align Left", systemImage: "text.alignleft") { richTextContext.applyAlignment(.left) }
                        MoreToolButton("Align Centre", systemImage: "text.aligncenter") { richTextContext.applyAlignment(.center) }
                        MoreToolButton("Align Right", systemImage: "text.alignright") { richTextContext.applyAlignment(.right) }
                        MoreToolButton("Justify", systemImage: "text.justify") { richTextContext.applyAlignment(.justified) }
                    }

                    MoreToolsSection(title: "Lists", systemImage: "list.bullet") {
                        MoreToolButton("Bulleted List", systemImage: "list.bullet") { richTextContext.toggleList(ordered: false) }
                        MoreToolButton("Numbered List", systemImage: "list.number") { richTextContext.toggleList(ordered: true) }
                    }

                    MoreToolsSection(title: "Fonts", systemImage: "textformat.size") {
                        Menu {
                            ForEach(FontOption.all) { option in
                                Button(option.label) {
                                    richTextContext.applyFont(name: option.id)
                                }
                            }
                        } label: {
                            MoreToolMenuLabel(
                                title: "Font",
                                detail: settings.flatMap { fontLabel($0.fontName) } ?? "Typeface",
                                systemImage: "textformat"
                            )
                        }
                        .accessibilityLabel("Font")

                        Menu {
                            ForEach(FontSizeOption.all) { option in
                                Button(option.label) {
                                    settings?.fontSize = option.size
                                    settings?.readerFontSize = option.size
                                    settings?.updatedAt = Date()
                                    if settings != nil {
                                        ScriptoriumActions.save(viewContext)
                                    }
                                    richTextContext.applyFontSize(CGFloat(option.size))
                                }
                            }
                        } label: {
                            MoreToolMenuLabel(
                                title: "Font Size",
                                detail: settings.map { "\(Int($0.fontSize)) pt" } ?? "Size",
                                systemImage: "textformat.size"
                            )
                        }
                        .accessibilityLabel("Font size")
                    }
                }
                .padding(16)
            }
            .navigationTitle("More Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func fontLabel(_ fontName: String) -> String {
        FontOption.all.first { $0.id == fontName }?.label ?? "Font"
    }
}

private struct MoreToolsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(SBTheme.primary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 10)], spacing: 10) {
                content
            }
        }
        .padding(14)
        .background(SBTheme.ivory.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SBTheme.border, lineWidth: 1)
        )
    }
}

private struct MoreToolButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .lineLimit(2)
        }
        .buttonStyle(.bordered)
        .tint(SBTheme.primary)
        .accessibilityLabel(title)
        .help(title)
    }
}

private struct MoreToolMenuLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(SBTheme.mutedForeground)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 44)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(SBTheme.parchment.opacity(0.46), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SBTheme.border, lineWidth: 1)
        )
    }
}

private enum SaveState {
    case saved
    case saving
    case manual
    case failed

    var label: String {
        switch self {
        case .saved: return "Saved"
        case .saving: return "Saving..."
        case .manual: return "Unsaved"
        case .failed: return "Save Failed"
        }
    }

    var tint: Color {
        switch self {
        case .saved: return ScriptoriumPalette.teal
        case .saving: return ScriptoriumPalette.amber
        case .manual: return SBTheme.crimson
        case .failed: return SBTheme.crimson
        }
    }
}

private extension UIColor {
    func isVisuallyEqual(to other: UIColor, tolerance: CGFloat = 0.035) -> Bool {
        let left = rgba
        let right = other.rgba
        return abs(left.red - right.red) <= tolerance
            && abs(left.green - right.green) <= tolerance
            && abs(left.blue - right.blue) <= tolerance
            && abs(left.alpha - right.alpha) <= tolerance
    }

    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
}

private final class EditorDraftBuffer: ObservableObject {
    private var latest = NSAttributedString()
    private(set) var hasPendingChanges = false

    func load(_ text: NSAttributedString) {
        latest = text.copy() as? NSAttributedString ?? NSAttributedString(attributedString: text)
        hasPendingChanges = false
    }

    func update(_ text: NSAttributedString) {
        latest = text.copy() as? NSAttributedString ?? NSAttributedString(attributedString: text)
        hasPendingChanges = true
    }

    func markPersisted(_ text: NSAttributedString) {
        latest = text.copy() as? NSAttributedString ?? NSAttributedString(attributedString: text)
        hasPendingChanges = false
    }

    func currentText(fallback: NSAttributedString) -> NSAttributedString {
        latest.length == 0 && !hasPendingChanges ? fallback : latest
    }
}

private struct EditorSaveError: Identifiable {
    let id = UUID()
    let message: String
}

private struct SaveErrorBanner: View {
    let error: EditorSaveError
    let retry: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SBTheme.crimson)
            VStack(alignment: .leading, spacing: 2) {
                Text("Autosave could not finish")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SBTheme.primary)
                Text(error.message)
                    .font(.caption2)
                    .foregroundStyle(SBTheme.mutedForeground)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button("Retry", action: retry)
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(SBTheme.mutedForeground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SBTheme.warning.opacity(0.18))
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
                                settings.editorFontName = $0
                                settings.updatedAt = Date()
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
                                    settings.readerFontSize = $0
                                    settings.updatedAt = Date()
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
                                    settings.updatedAt = Date()
                                    ScriptoriumActions.save(viewContext)
                                }
                            ), in: 0...14, step: 1)
                        }
                    }

                    Section("Default Style") {
                        Toggle("Bold", isOn: Binding(
                            get: { settings.defaultBold },
                            set: { settings.defaultBold = $0; settings.updatedAt = Date(); ScriptoriumActions.save(viewContext) }
                        ))
                        Toggle("Italic", isOn: Binding(
                            get: { settings.defaultItalic },
                            set: { settings.defaultItalic = $0; settings.updatedAt = Date(); ScriptoriumActions.save(viewContext) }
                        ))
                        Toggle("Underline", isOn: Binding(
                            get: { settings.defaultUnderline },
                            set: { settings.defaultUnderline = $0; settings.updatedAt = Date(); ScriptoriumActions.save(viewContext) }
                        ))
                    }

                    Section("Preview") {
                        Text("In the beginning was the Word.")
                            .font(.custom(settings.fontName, size: CGFloat(settings.fontSize)))
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

#Preview("Chapter Editor") {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext
    let chapters = (try? context.fetch(SBChapter.fetchRequest())) ?? []
    let settings = (try? context.fetch(SBAppSettings.fetchRequest()))?.first
    let chapter = chapters.first
    let book = chapter?.book

    return NavigationStack {
        if let chapter, let book {
            EditorView(
                chapter: chapter,
                book: book,
                settings: settings,
                selectedText: .constant("")
            )
        } else {
            EmptyStateView(title: "No Preview Chapter", message: "The preview seed did not create a chapter.", systemImage: "text.book.closed")
        }
    }
    .environment(\.managedObjectContext, context)
}
