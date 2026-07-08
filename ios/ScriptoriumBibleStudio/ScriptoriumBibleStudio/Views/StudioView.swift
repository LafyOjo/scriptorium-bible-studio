import CoreData
import SwiftUI

struct StudioView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBBook.orderIndex, ascending: true)])
    private var books: FetchedResults<SBBook>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBChapter.updatedAt, ascending: false)])
    private var chapters: FetchedResults<SBChapter>

    @FetchRequest(sortDescriptors: [
        NSSortDescriptor(keyPath: \SBCollection.orderIndex, ascending: true),
        NSSortDescriptor(keyPath: \SBCollection.name, ascending: true),
    ])
    private var collections: FetchedResults<SBCollection>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBBookmark.createdAt, ascending: false)])
    private var bookmarks: FetchedResults<SBBookmark>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBNote.createdAt, ascending: false)])
    private var notes: FetchedResults<SBNote>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SBAppSettings.id, ascending: true)])
    private var appSettings: FetchedResults<SBAppSettings>

    @State private var selectedSection: StudioSection = .dashboard
    @State private var selectedChapterID: String?
    @State private var selectedText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var compactEditorPane: CompactEditorPane = .write

    private var activeChapter: SBChapter? {
        if let selectedChapterID,
           let chapter = chapters.first(where: { $0.id == selectedChapterID }) {
            return chapter
        }
        return chapters.first
    }

    private var activeBook: SBBook? {
        activeChapter?.book
    }

    private var settings: SBAppSettings? {
        appSettings.first
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactShell
            } else {
                regularShell
            }
        }
        .onAppear {
            if selectedChapterID == nil {
                selectedChapterID = chapters.first?.id
            }
        }
        .onChange(of: selectedSection) { _, newValue in
            if newValue == .editor {
                compactEditorPane = .write
            }
        }
    }

    private var regularShell: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedSection: $selectedSection,
                selectedChapterID: $selectedChapterID,
                books: Array(books),
                chapters: Array(chapters),
                collections: Array(collections),
                settings: settings,
                openChapter: openChapter
            )
            .navigationTitle("Scriptorium")
        } content: {
            contentView
                .navigationTitle(selectedSection.title)
                .studioBackground()
        } detail: {
            InspectorView(
                chapter: activeChapter,
                book: activeBook,
                selectedText: $selectedText,
                bookmarks: Array(bookmarks)
            )
            .studioBackground()
        }
    }

    private var compactShell: some View {
        TabView(selection: $selectedSection) {
            NavigationStack {
                DashboardView(
                    books: Array(books),
                    chapters: Array(chapters),
                    bookmarks: Array(bookmarks),
                    openChapter: openChapter,
                    openLibrary: { selectedSection = .library }
                )
                .navigationTitle(StudioSection.dashboard.title)
                .studioBackground()
            }
            .tabItem {
                Label(StudioSection.dashboard.title, systemImage: StudioSection.dashboard.systemImage)
            }
            .tag(StudioSection.dashboard)

            NavigationStack {
                LibraryView(
                    books: Array(books),
                    chapters: Array(chapters),
                    settings: settings,
                    openChapter: openChapter
                )
                .navigationTitle(StudioSection.library.title)
                .studioBackground()
            }
            .tabItem {
                Label(StudioSection.library.title, systemImage: StudioSection.library.systemImage)
            }
            .tag(StudioSection.library)

            NavigationStack {
                compactEditorContent
                    .navigationTitle(StudioSection.editor.title)
                    .studioBackground()
            }
            .tabItem {
                Label(StudioSection.editor.title, systemImage: StudioSection.editor.systemImage)
            }
            .tag(StudioSection.editor)

            NavigationStack {
                SearchView(
                    chapters: Array(chapters),
                    books: Array(books),
                    openChapter: openChapter
                )
                .navigationTitle(StudioSection.search.title)
                .studioBackground()
            }
            .tabItem {
                Label(StudioSection.search.title, systemImage: StudioSection.search.systemImage)
            }
            .tag(StudioSection.search)

            NavigationStack {
                SettingsView(
                    books: Array(books),
                    chapters: Array(chapters),
                    collections: Array(collections),
                    notes: Array(notes),
                    bookmarks: Array(bookmarks),
                    settings: settings
                )
                .navigationTitle(StudioSection.settings.title)
                .studioBackground()
            }
            .tabItem {
                Label(StudioSection.settings.title, systemImage: StudioSection.settings.systemImage)
            }
            .tag(StudioSection.settings)
        }
    }

    @ViewBuilder
    private var compactEditorContent: some View {
        if let activeChapter, let activeBook {
            VStack(spacing: 0) {
                Picker("Editor workspace", selection: $compactEditorPane) {
                    ForEach(CompactEditorPane.allCases) { pane in
                        Label(pane.title, systemImage: pane.systemImage).tag(pane)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.bar)

                if compactEditorPane == .write {
                    EditorView(
                        chapter: activeChapter,
                        book: activeBook,
                        settings: settings,
                        selectedText: $selectedText
                    )
                } else {
                    InspectorView(
                        chapter: activeChapter,
                        book: activeBook,
                        selectedText: $selectedText,
                        bookmarks: Array(bookmarks)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyStateView(
                title: "No Chapter Selected",
                message: "Create or select a chapter to begin writing.",
                systemImage: "text.book.closed"
            )
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(
                books: Array(books),
                chapters: Array(chapters),
                bookmarks: Array(bookmarks),
                openChapter: openChapter,
                openLibrary: { selectedSection = .library }
            )
        case .library:
            LibraryView(
                books: Array(books),
                chapters: Array(chapters),
                settings: settings,
                openChapter: openChapter
            )
        case .editor:
            if let activeChapter, let activeBook {
                EditorView(
                    chapter: activeChapter,
                    book: activeBook,
                    settings: settings,
                    selectedText: $selectedText
                )
            } else {
                EmptyStateView(
                    title: "No Chapter Selected",
                    message: "Create or select a chapter to begin writing.",
                    systemImage: "text.book.closed"
                )
            }
        case .search:
            SearchView(
                chapters: Array(chapters),
                books: Array(books),
                openChapter: openChapter
            )
        case .settings:
            SettingsView(
                books: Array(books),
                chapters: Array(chapters),
                collections: Array(collections),
                notes: Array(notes),
                bookmarks: Array(bookmarks),
                settings: settings
            )
        }
    }

    private func openChapter(_ chapter: SBChapter) {
        selectedChapterID = chapter.id
        selectedSection = .editor
        compactEditorPane = .write
    }
}

private enum CompactEditorPane: String, CaseIterable, Identifiable {
    case write
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .write: return "Write"
        case .tools: return "Tools"
        }
    }

    var systemImage: String {
        switch self {
        case .write: return "pencil.line"
        case .tools: return "sidebar.right"
        }
    }
}
