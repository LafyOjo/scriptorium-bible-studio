import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var persistence: PersistenceController
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    let books: [SBBook]
    let chapters: [SBChapter]
    let collections: [SBCollection]
    let notes: [SBNote]
    let bookmarks: [SBBookmark]
    let settings: SBAppSettings?

    @State private var shareItem: ShareItem?
    @State private var importPresented = false
    @State private var resetAlertPresented = false
    @State private var errorMessage: String?

    private var completedChapters: Int {
        chapters.filter { $0.statusValue == .final }.count
    }

    private var voiceOptions: [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted {
                if $0.language == $1.language {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.language < $1.language
            }
            .map { VoiceOption(id: $0.identifier, name: $0.name, language: $0.language) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let settings {
                    appearanceSection(settings)
                    editorSection(settings)
                    narrationSection(settings)
                    onboardingSection
                    backupSection
                    librarySnapshot
                } else {
                    ParchmentPanel {
                        ErrorStateView(
                            title: "Settings Could Not Load",
                            message: "The local settings record is missing. Restarting the app will regenerate defaults."
                        ) {
                            persistence.ensureSettings(context: viewContext)
                        }
                        .frame(minHeight: 320)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .navigationTitle("Settings")
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .fileImporter(
            isPresented: $importPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importBackup(result)
        }
        .alert("Reset starter library?", isPresented: $resetAlertPresented) {
            Button("Reset", role: .destructive) {
                persistence.resetToSeed(context: viewContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces your current local manuscript with the starter Scriptorium library.")
        }
        .alert("Settings Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        ParchmentPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Studio Preferences")
                            .font(SBTheme.display(11, weight: .semibold))
                            .tracking(2.4)
                            .foregroundStyle(SBTheme.crimson)
                            .textCase(.uppercase)
                        Text("Shape the writing room")
                            .font(SBTheme.body(34, weight: .semibold))
                            .foregroundStyle(SBTheme.primary)
                            .minimumScaleFactor(0.74)
                    }

                    Spacer()

                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(SBTheme.gold)
                        .frame(width: 52, height: 52)
                        .background(SBTheme.goldSoft.opacity(0.22), in: Circle())
                }

                Text("Tune the manuscript editor, reader, narration and export behavior for a long-form Bible writing practice.")
                    .font(.callout)
                    .foregroundStyle(SBTheme.mutedForeground)
                    .lineSpacing(2)
            }
        }
    }

    private func appearanceSection(_ settings: SBAppSettings) -> some View {
        SettingsSection(title: "Appearance", subtitle: "Theme, reading size and manuscript typography", systemImage: "paintpalette") {
            Picker("Theme", selection: Binding(
                get: { SettingsTheme(rawValue: settings.theme ?? "parchment") ?? .parchment },
                set: { theme in
                    updateSettings { item in
                        item.theme = theme.rawValue
                    }
                }
            )) {
                ForEach(SettingsTheme.allCases) { theme in
                    Label(theme.label, systemImage: theme.systemImage).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            settingStepper(
                title: "Reader text size",
                value: Binding(
                    get: { settings.readerFontSize == 0 ? settings.fontSize : settings.readerFontSize },
                    set: { value in
                        updateSettings { item in
                            item.readerFontSize = value
                        }
                    }
                ),
                range: 14...34,
                suffix: "pt"
            )

            Picker("Manuscript typeface", selection: Binding(
                get: { settings.fontName },
                set: { value in
                    updateSettings { item in
                        item.fontName = value
                        item.editorFontName = value
                    }
                }
            )) {
                ForEach(FontOption.all) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .pickerStyle(.menu)

            Text("In the beginning was the Word, and the manuscript waits for your voice.")
                .font(.custom(settings.fontName, size: CGFloat(settings.fontSize)))
                .foregroundStyle(SBTheme.ink)
                .lineSpacing(settings.lineSpacing)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SBTheme.parchment.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func editorSection(_ settings: SBAppSettings) -> some View {
        SettingsSection(title: "Editor", subtitle: "Writing defaults and autosave behavior", systemImage: "pencil.line") {
            Toggle("Autosave while writing", isOn: Binding(
                get: { settings.autosaveEnabled },
                set: { value in
                    updateSettings { item in
                        item.autosaveEnabled = value
                    }
                }
            ))
            .tint(SBTheme.primary)

            settingStepper(
                title: "Editor font size",
                value: Binding(
                    get: { settings.fontSize },
                    set: { value in
                        updateSettings { item in
                            item.fontSize = value
                            if item.readerFontSize == 0 {
                                item.readerFontSize = value
                            }
                        }
                    }
                ),
                range: 12...34,
                suffix: "pt"
            )

            settingStepper(
                title: "Line spacing",
                value: Binding(
                    get: { settings.lineSpacing },
                    set: { value in
                        updateSettings { item in
                            item.lineSpacing = value
                        }
                    }
                ),
                range: 0...14,
                suffix: ""
            )

            Toggle("Bold by default", isOn: Binding(
                get: { settings.defaultBold },
                set: { value in updateSettings { $0.defaultBold = value } }
            ))
            Toggle("Italic by default", isOn: Binding(
                get: { settings.defaultItalic },
                set: { value in updateSettings { $0.defaultItalic = value } }
            ))
            Toggle("Underline by default", isOn: Binding(
                get: { settings.defaultUnderline },
                set: { value in updateSettings { $0.defaultUnderline = value } }
            ))
        }
    }

    private func narrationSection(_ settings: SBAppSettings) -> some View {
        SettingsSection(title: "Read Aloud", subtitle: "Voice and pace for listening through drafts", systemImage: "speaker.wave.2") {
            Picker("Voice", selection: Binding(
                get: { settings.voiceIdentifier ?? "" },
                set: { value in
                    updateSettings { item in
                        item.voiceIdentifier = value.isEmpty ? nil : value
                    }
                }
            )) {
                Text("System Default").tag("")
                ForEach(voiceOptions) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Speed", systemImage: "speedometer")
                    Spacer()
                    Text(settings.readAloudRate, format: .number.precision(.fractionLength(2)))
                        .foregroundStyle(SBTheme.mutedForeground)
                }
                .font(.callout.weight(.medium))

                Slider(value: Binding(
                    get: { settings.readAloudRate == 0 ? 0.48 : settings.readAloudRate },
                    set: { value in
                        updateSettings { item in
                            item.readAloudRate = value
                        }
                    }
                ), in: 0.36...0.62, step: 0.01)
                .tint(SBTheme.gold)
            }
        }
    }

    private var onboardingSection: some View {
        SettingsSection(title: "Onboarding", subtitle: "Replay the guided tour for the studio workflow", systemImage: "sparkles") {
            Button {
                hasCompletedOnboarding = false
            } label: {
                Label("Show Onboarding Again", systemImage: "play.rectangle")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(SBTheme.primary)
        }
    }

    private var backupSection: some View {
        SettingsSection(title: "Export And Backup", subtitle: "Move your manuscript data safely", systemImage: "externaldrive") {
            Button {
                exportBackup()
            } label: {
                Label("Export JSON Backup", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(SBTheme.primary)

            Button {
                importPresented = true
            } label: {
                Label("Import JSON Backup", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(SBTheme.primary)

            Button(role: .destructive) {
                resetAlertPresented = true
            } label: {
                Label("Reset Starter Library", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    private var librarySnapshot: some View {
        SettingsSection(title: "Library Health", subtitle: "Local writing inventory", systemImage: "books.vertical") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                SettingsMetric(title: "Books", value: "\(books.count)", systemImage: "books.vertical")
                SettingsMetric(title: "Chapters", value: "\(chapters.count)", systemImage: "text.book.closed")
                SettingsMetric(title: "Final", value: "\(completedChapters)", systemImage: "checkmark.seal")
                SettingsMetric(title: "Notes", value: "\(notes.count)", systemImage: "note.text")
                SettingsMetric(title: "Bookmarks", value: "\(bookmarks.count)", systemImage: "bookmark")
                SettingsMetric(title: "Collections", value: "\(collections.count)", systemImage: "folder")
            }
        }
    }

    private func settingStepper(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.callout.weight(.medium))
            Spacer()
            Stepper(value: value, in: range, step: 1) {
                Text("\(Int(value.wrappedValue))\(suffix.isEmpty ? "" : " \(suffix)")")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(SBTheme.primary)
                    .frame(minWidth: 58, alignment: .trailing)
            }
            .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    private func updateSettings(_ changes: (SBAppSettings) -> Void) {
        guard let settings else { return }
        changes(settings)
        settings.updatedAt = Date()
        ScriptoriumActions.save(viewContext)
    }

    private func exportBackup() {
        do {
            let backup = BackupService.makeBackup(
                books: books,
                chapters: chapters,
                collections: collections,
                notes: notes,
                bookmarks: bookmarks,
                settings: settings
            )
            let data = try BackupService.encode(backup)
            shareItem = ShareItem(url: try ExportService.backupURL(data: data))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            let backup = try BackupService.decode(data)
            BackupService.restore(backup, persistence: persistence, context: viewContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        ParchmentPanel(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SBTheme.gold)
                        .frame(width: 36, height: 36)
                        .background(SBTheme.goldSoft.opacity(0.24), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(SBTheme.body(24, weight: .semibold))
                            .foregroundStyle(SBTheme.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(SBTheme.mutedForeground)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    content
                }
            }
        }
    }
}

private struct SettingsMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(SBTheme.gold)
            Text(value)
                .font(SBTheme.display(24, weight: .semibold))
                .foregroundStyle(SBTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title.uppercased())
                .font(SBTheme.display(9, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(SBTheme.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SBTheme.parchment.opacity(0.56), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private enum SettingsTheme: String, CaseIterable, Identifiable {
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
}

private struct VoiceOption: Identifiable {
    let id: String
    let name: String
    let language: String

    var label: String {
        "\(name) (\(language))"
    }
}

#Preview("Settings") {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext
    let books = (try? context.fetch(SBBook.fetchRequest())) ?? []
    let chapters = (try? context.fetch(SBChapter.fetchRequest())) ?? []
    let collections = (try? context.fetch(SBCollection.fetchRequest())) ?? []
    let notes = (try? context.fetch(SBNote.fetchRequest())) ?? []
    let bookmarks = (try? context.fetch(SBBookmark.fetchRequest())) ?? []
    let settings = (try? context.fetch(SBAppSettings.fetchRequest()))?.first

    return NavigationStack {
        SettingsView(
            books: books,
            chapters: chapters,
            collections: collections,
            notes: notes,
            bookmarks: bookmarks,
            settings: settings
        )
        .studioBackground()
    }
    .environment(\.managedObjectContext, context)
    .environmentObject(controller)
}
