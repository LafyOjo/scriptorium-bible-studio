import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var persistence: PersistenceController

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

    var body: some View {
        Form {
            if let settings {
                Section("Writing Defaults") {
                    Picker("Typeface", selection: Binding(
                        get: { settings.fontName },
                        set: {
                            settings.fontName = $0
                            settings.editorFontName = $0
                            settings.updatedAt = Date()
                            ScriptoriumActions.save(viewContext)
                        }
                    )) {
                        ForEach(FontOption.all) { option in
                            Text(option.label).tag(option.id)
                        }
                    }

                    LabeledContent("Font Size") {
                        Stepper("\(Int(settings.fontSize)) pt", value: Binding(
                            get: { settings.fontSize },
                            set: {
                                settings.fontSize = $0
                                settings.readerFontSize = $0
                                settings.updatedAt = Date()
                                ScriptoriumActions.save(viewContext)
                            }
                        ), in: 12...34, step: 1)
                    }

                    LabeledContent("Line Spacing") {
                        Stepper("\(Int(settings.lineSpacing))", value: Binding(
                            get: { settings.lineSpacing },
                            set: {
                                settings.lineSpacing = $0
                                settings.updatedAt = Date()
                                ScriptoriumActions.save(viewContext)
                            }
                        ), in: 0...14, step: 1)
                    }

                    Toggle("Bold by default", isOn: Binding(
                        get: { settings.defaultBold },
                        set: { settings.defaultBold = $0; settings.updatedAt = Date(); ScriptoriumActions.save(viewContext) }
                    ))
                    Toggle("Italic by default", isOn: Binding(
                        get: { settings.defaultItalic },
                        set: { settings.defaultItalic = $0; settings.updatedAt = Date(); ScriptoriumActions.save(viewContext) }
                    ))
                    Toggle("Underline by default", isOn: Binding(
                        get: { settings.defaultUnderline },
                        set: { settings.defaultUnderline = $0; settings.updatedAt = Date(); ScriptoriumActions.save(viewContext) }
                    ))

                    VStack(alignment: .leading) {
                        Text("Read Aloud Rate: \(settings.readAloudRate, specifier: "%.2f")")
                        Slider(value: Binding(
                            get: { settings.readAloudRate == 0 ? 0.48 : settings.readAloudRate },
                            set: {
                                settings.readAloudRate = $0
                                settings.updatedAt = Date()
                                ScriptoriumActions.save(viewContext)
                            }
                        ), in: 0.36...0.62, step: 0.01)
                    }
                }
            }

            Section("Library Snapshot") {
                LabeledContent("Books", value: "\(books.count)")
                LabeledContent("Chapters", value: "\(chapters.count)")
                LabeledContent("Notes", value: "\(notes.count)")
                LabeledContent("Bookmarks", value: "\(bookmarks.count)")
                LabeledContent("Collections", value: "\(collections.count)")
            }

            Section("Backup and Restore") {
                Button {
                    exportBackup()
                } label: {
                    Label("Export JSON Backup", systemImage: "square.and.arrow.up")
                }

                Button {
                    importPresented = true
                } label: {
                    Label("Import JSON Backup", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    resetAlertPresented = true
                } label: {
                    Label("Reset Sample Library", systemImage: "arrow.counterclockwise")
                }
            }
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
        .alert("Reset library?", isPresented: $resetAlertPresented) {
            Button("Reset", role: .destructive) {
                persistence.resetToSeed(context: viewContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the current Core Data library with the sample Scriptorium starter content.")
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
